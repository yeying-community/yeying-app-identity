
This is a project for web application to tell user 'whoami and registry'.


how to start server?

create a application identity and move to `run/app.id`

and then

script/runner.sh -e <dev or prod>

for dev
curl http://localhost:8541/whoami
curl http://localhost:8541/registry


for prod
curl http://localhost:8542/whoami
curl http://localhost:8542/registry

and then config your nginx location, you can access like this:
curl https://<domain>:whoami

