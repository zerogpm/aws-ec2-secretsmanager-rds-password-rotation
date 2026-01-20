#!/bin/bash
set -e
exec > /var/log/user-data.log 2>&1

dnf update -y
dnf install -y nodejs npm nginx

mkdir -p /opt/app && cd /opt/app

cat > package.json << 'EOF'
{"name":"app","dependencies":{"express":"^4.18.2","@aws-sdk/client-secrets-manager":"^3.400.0","mysql2":"^3.6.0"}}
EOF

npm install

cat > server.js << 'EOF'
const express = require('express');
const { SecretsManagerClient, GetSecretValueCommand } = require('@aws-sdk/client-secrets-manager');
const mysql = require('mysql2/promise');
const app = express();
const REGION = '${aws_region}', SECRET = '${secret_name}', DB = '${db_name}';

app.get('/api/test-connection', async (req, res) => {
  const r = { status: 'unknown', message: '', details: {} };
  let secret;
  try {
    const c = new SecretsManagerClient({ region: REGION });
    const resp = await c.send(new GetSecretValueCommand({ SecretId: SECRET }));
    secret = JSON.parse(resp.SecretString);
    r.details = { secrets_manager: 'success', host: secret.host, port: secret.port, username: secret.username };
  } catch (e) {
    r.status = 'error';
    r.error_type = e.name === 'ResourceNotFoundException' ? 'SECRET_NOT_FOUND' : e.name === 'AccessDeniedException' ? 'ACCESS_DENIED' : 'SECRETS_ERROR';
    r.message = e.message;
    return res.status(500).json(r);
  }
  let conn;
  try {
    conn = await mysql.createConnection({ host: secret.host, port: +secret.port, user: secret.username, password: secret.password, database: DB, connectTimeout: 10000 });
    const [[v]] = await conn.execute('SELECT VERSION() as v');
    const [[d]] = await conn.execute('SELECT DATABASE() as d');
    r.details.mysql_version = v.v;
    r.details.database = d.d;
    await conn.end();
    r.status = 'success';
    r.message = 'Connected to RDS MySQL';
    return res.json(r);
  } catch (e) {
    if (conn) try { await conn.end(); } catch (_) {}
    r.status = 'error';
    r.details.error_code = e.errno || e.code;
    r.error_type = e.errno === 1045 ? 'INVALID_CREDENTIALS' : e.code === 'ECONNREFUSED' ? 'CONNECTION_REFUSED' : e.code === 'ETIMEDOUT' ? 'TIMEOUT' : 'MYSQL_ERROR';
    r.message = e.message;
    return res.status(500).json(r);
  }
});
app.get('/api/health', (_, res) => res.json({ status: 'ok' }));
app.listen(3000, '127.0.0.1');
EOF

cat > /etc/systemd/system/app.service << 'EOF'
[Unit]
Description=App
After=network.target
[Service]
WorkingDirectory=/opt/app
ExecStart=/usr/bin/node server.js
Restart=always
[Install]
WantedBy=multi-user.target
EOF

cat > /usr/share/nginx/html/index.html << 'EOF'
<!DOCTYPE html><html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>RDS Tester</title>
<style>*{margin:0;padding:0;box-sizing:border-box}body{font-family:system-ui;background:#1a1a2e;min-height:100vh;display:flex;justify-content:center;align-items:center;padding:20px}.c{background:#fff;border-radius:16px;padding:40px;max-width:600px;width:100%}h1{margin-bottom:10px}.sub{color:#666;margin-bottom:30px}.btn{background:linear-gradient(135deg,#667eea,#764ba2);color:#fff;border:0;padding:15px;font-size:16px;border-radius:8px;cursor:pointer;width:100%}.btn:disabled{background:#ccc}.r{margin-top:20px;padding:20px;border-radius:12px}.r.success{background:#d4edda}.r.error{background:#f8d7da}.r.loading{background:#fff3cd}.d{background:rgba(0,0,0,.05);border-radius:8px;padding:15px;margin-top:15px}.dr{display:flex;justify-content:space-between;padding:5px 0;border-bottom:1px solid rgba(0,0,0,.1)}.dr:last-child{border:0}.et{background:#dc3545;color:#fff;padding:4px 12px;border-radius:20px;font-size:12px;display:inline-block;margin-bottom:10px}</style></head>
<body><div class="c"><h1>RDS Connection Tester</h1><p class="sub">Test MySQL connectivity via Secrets Manager</p>
<button class="btn" id="btn">Test Connection</button><div id="out"></div></div>
<script>
var btn=document.getElementById('btn'),out=document.getElementById('out');
btn.onclick=function(){btn.disabled=true;out.innerHTML='<div class="r loading">Testing...</div>';
fetch('/api/test-connection').then(function(res){return res.json();}).then(function(data){
var det='';if(data.details){for(var k in data.details){det+='<div class="dr"><span>'+k+'</span><span>'+data.details[k]+'</span></div>';}}
out.innerHTML='<div class="r '+data.status+'">'+(data.error_type?'<span class="et">'+data.error_type+'</span>':'')+'<h3>'+(data.status==='success'?'Success!':'Failed')+'</h3><p>'+data.message+'</p>'+(det?'<div class="d">'+det+'</div>':'')+'</div>';
btn.disabled=false;}).catch(function(e){out.innerHTML='<div class="r error"><h3>Error</h3><p>'+e.message+'</p></div>';btn.disabled=false;});};
</script></body></html>
EOF

cat > /etc/nginx/conf.d/app.conf << 'EOF'
server{listen 80;root /usr/share/nginx/html;location /{try_files $uri /index.html;}location /api/{proxy_pass http://127.0.0.1:3000;}}
EOF

rm -f /etc/nginx/conf.d/default.conf
systemctl daemon-reload && systemctl enable --now app nginx
