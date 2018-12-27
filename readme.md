# Snake

A Snake game written in Nim targetting JavaScript in a web browser:
http://picheta.me/snake/.

## Systemd setup

Create a ``snake.service`` file in ``/lib/systemd/system/`` (or any of the other locations described [here](https://askubuntu.com/questions/876733/where-are-the-systemd-units-services-located-in-ubuntu)), put this in it:

```systemd
[Unit]
Description=snake
After=network.target httpd.service
Wants=network-online.target

[Service]
Environment=IPSTACK_KEY=<YOUR_IPSTACK_KEY_HERE>
Type=simple
WorkingDirectory=/home/user/dev/snake/
ExecStart=/usr/bin/stdbuf -oL /home/user/dev/snake/snake/server
Restart=always
RestartSec=2

User=dom

[Install]
WantedBy=multi-user.target
```
