# SPDX-FileCopyrightText: 2026 first-uninteresting-username
#
# SPDX-License-Identifier: GPL-3.0-or-later
# Claude sessions inside and outside ~/Agents report to a recording fake Hackatime API.
# AI heartbeats may reach it only for ~/Agents; human heartbeats are always sent.
{
  pkgs,
  package,
}: let
  inherit (pkgs) lib;
  fakeApi = pkgs.writeText "fake-hackatime.py" ''
    import json, http.server

    class Handler(http.server.BaseHTTPRequestHandler):
        def do_POST(self):
            data = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
            data = data if isinstance(data, list) else [data]
            with open("/var/lib/hackatime/heartbeats.jsonl", "a") as log:
                for heartbeat in data:
                    log.write(json.dumps(heartbeat) + "\n")
            body = json.dumps(
                {"responses": [[{"data": {"id": str(i)}}, 201] for i in range(len(data))]}
            ).encode()
            self.send_response(202)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

    http.server.HTTPServer(("127.0.0.1", 8000), Handler).serve_forever()
  '';
  makeCheck = regression: let
    wakatime =
      if regression
      then
        package.overrideAttrs (previous: {
          patches = lib.remove ../_exclude-ai-session-project-path.diff previous.patches;
          doCheck = false;
        })
      else package;
  in
    pkgs.testers.runNixOSTest {
      name = "wakatime-exclude-ai${lib.optionalString regression "-regression"}";
      nodes.machine = {
        users.users.u = {
          isNormalUser = true;
          home = "/home/u";
        };
        environment.systemPackages = [wakatime];
        systemd.tmpfiles.rules = ["d /var/lib/hackatime 0777 root root -"];
        systemd.services.fake-hackatime = {
          wantedBy = ["multi-user.target"];
          serviceConfig.ExecStart = "${lib.getExe pkgs.python3} ${fakeApi}";
        };
      };
      testScript = ''
        import json
        from datetime import datetime, timedelta, timezone

        # (working directory, session, project name, whether Claude edited a file)
        sessions = [
            ("/home/u/Agents/edit", "11111111-0000-4000-8000-000000000001", "agents-edit", True),
            ("/home/u/Agents/chat", "11111111-0000-4000-8000-000000000002", "agents-chat", False),
            ("/home/u/Projects/edit", "22222222-0000-4000-8000-000000000001", "projects-edit", True),
            ("/home/u/Projects/chat", "22222222-0000-4000-8000-000000000002", "projects-chat", False),
        ]

        def transcript(cwd, session, edit):
            now = datetime.now(timezone.utc)
            stamp = lambda minutes: (now - timedelta(minutes=minutes)).strftime("%Y-%m-%dT%H:%M:%S.000Z")
            common = {"sessionId": session, "version": "2.1.0", "cwd": cwd, "type": "user"}
            lines = [{
                **common, "timestamp": stamp(10), "isSidechain": False,
                "message": {"role": "user", "content": [{"type": "text", "text": "edit main.go"}]},
            }]
            if edit:
                lines.append({
                    **common, "timestamp": stamp(9),
                    "toolUseResult": {"filePath": f"{cwd}/main.go",
                                      "structuredPatch": [{"oldLines": 1, "newLines": 3}]},
                    "message": {"role": "user", "content": [{"type": "tool_result", "content": "ok"}],
                                "usage": {"input_tokens": 10, "output_tokens": 5}},
                })
            return "".join(json.dumps(line) + "\n" for line in lines)

        def reset():
            machine.succeed("rm -rf /home/u/{.wakatime,.claude,Agents,Projects}")
            machine.succeed(": > /var/lib/hackatime/heartbeats.jsonl")
            for cwd, session, project, edit in sessions:
                slug = cwd.replace("/", "-")
                machine.succeed(f"mkdir -p {cwd} /home/u/.claude/projects/{slug}")
                machine.succeed(f"echo {project} > {cwd}/.wakatime-project")
                machine.succeed(f"echo 'package main' > {cwd}/main.go")
                machine.succeed(f"cat > /home/u/.claude/projects/{slug}/{session}.jsonl <<'EOF'\n"
                                f"{transcript(cwd, session, edit)}EOF")
            machine.succeed("""cat > /home/u/.wakatime.cfg <<'EOF'
        [settings]
        api_url = http://127.0.0.1:8000/api/v1
        api_key = 00000000-0000-4000-8000-000000000000
        sync_ai_disabled = false
        exclude_ai = ^(?!/home/u/Agents(/|$))
        EOF""")
            machine.succeed("chown -R u:users /home/u")

        machine.wait_for_unit("fake-hackatime.service")
        machine.wait_for_open_port(8000)

        # Claude Code runs AI sync directly; editor plugins trigger it with a human heartbeat.
        for name, arguments in [
            ("ai sync", "--sync-ai-activity"),
            ("editor heartbeat", "--entity /home/u/Projects/edit/main.go --write --plugin 'zed/1 zed-wakatime/1'"),
        ]:
            with subtest(name):
                reset()
                machine.succeed(f"su u -c \"wakatime-cli {arguments}\"")
                heartbeats = [
                    json.loads(line)
                    for line in machine.succeed("cat /var/lib/hackatime/heartbeats.jsonl").splitlines()
                ]
                for heartbeat in heartbeats:
                    print(heartbeat.get("category"), heartbeat["type"], heartbeat["entity"], heartbeat.get("project"))
                ai = [h for h in heartbeats if h.get("category") == "ai coding"]
                leaked = sorted({h["entity"] for h in ai if not h.get("project", "").startswith("agents-")})
                assert not leaked, f"CHECKS_V2_REGRESSION:wakatime-exclude-ai-session: {leaked}"
                kept = {h.get("project") for h in ai}
                assert kept == {"agents-edit", "agents-chat"}, f"~/Agents AI activity missing: {kept}"
                if name == "editor heartbeat":
                    assert any(h.get("category") != "ai coding" for h in heartbeats), "human heartbeat missing"
      '';
    };
in {
  check = makeCheck false;
  regression = makeCheck true;
}
