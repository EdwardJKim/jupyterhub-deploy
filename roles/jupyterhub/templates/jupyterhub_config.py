# Configuration file for Jupyter Hub
c = get_config()

import os
import sys

# Base configuration
c.JupyterHub.log_level = "DEBUG"
#c.JupyterHub.db_url = 'sqlite:////srv/jupyterhub_db/jupyterhub.sqlite'
c.JupyterHub.log_file = "/srv/jupyterhub/jupyterhub.log"

c.JupyterHub.cookie_secret_file = "/srv/jupyterhub/cookie_secret_file"
c.JupyterHub.proxy_auth_token = "{{ configproxy_auth_token }}"

# Configure the authenticator
c.JupyterHub.authenticator_class = 'oauthenticator.LocalGitHubOAuthenticator'

c.LocalGitHubOAuthenticator.github_client_id = "{{ github_client_id }}"
c.LocalGitHubOAuthenticator.github_client_secret = "{{ github_client_secret }}"
c.LocalGitHubOAuthenticator.oauth_callback_url = "{{ oauth_callback_url }}"
c.LocalGitHubOAuthenticator.create_system_users = True

# Configure the spawner
c.JupyterHub.spawner_class = 'swarmspawner.SwarmSpawner'
c.DockerSpawner.container_image = 'edwardjkim/singleuser'
c.DockerSpawner.tls_cert = '{{ docker_tls_path }}/cert.pem'
c.DockerSpawner.tls_key = '{{ docker_tls_path }}/key.pem'
c.DockerSpawner.remove_containers = True
c.DockerSpawner.read_only_volumes = {
    '/media/nfs/data': '/home/data_scientist/data',
    '/media/nfs/lessons': '/home/data_scientist/lessons',
    '/media/nfs/testing': '/home/data_scientist/testing',
}
# The docker instances need access to the Hub, so the default loopback port
# doesn't work:
c.JupyterHub.hub_ip = '{{ servicenet_ip }}'

# Add users to the admin list, the whitelist, and also record their user ids
#root = os.environ.get('OAUTHENTICATOR_DIR', os.path.dirname(__file__))
#sys.path.insert(0, root)
c.Authenticator.admin_users = admin = set()
c.Authenticator.whitelist = whitelist = set()

root = '/srv/jupyterhub'

with open(os.path.join(root, 'userlist')) as f:
    for line in f:
        if line.isspace():
            continue
        parts = line.split()
        name = parts[0]
        whitelist.add(name)
        if len(parts) > 1 and parts[1] == 'admin':
            admin.add(name)
