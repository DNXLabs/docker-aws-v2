import os
import json
import requests
import sys
import semver
import github3
from jinja2 import Environment, FileSystemLoader

LATEST_RELEASES_PATH_AWS_CLI = 'https://api.github.com/repos/aws/aws-cli/git/refs/tags'
LATEST_RELEASES_PATH_DNX_AWS_CLI = 'https://api.github.com/repos/DNXLabs/docker-aws-v2/releases/latest'
GITHUB_TOKEN = os.getenv('GITHUB_TOKEN')
GITHUB_REPOSITORY_ID = '368183359'
DEFAULT_BRANCH = os.getenv('DEFAULT_BRANCH', 'master')


# AWS-CLI upstream
response_release_aws_v2 = requests.get(
    LATEST_RELEASES_PATH_AWS_CLI,
    headers={'Authorization': 'token ' + GITHUB_TOKEN})
tags_tf_json_obj = json.loads(response_release_aws_v2.text)[-1]

tag_name_aws_cli = tags_tf_json_obj.get('ref').replace('refs/tags/', '')

# DNX docker-aws-v2
response_release_docker_aws_v2 = requests.get(
    LATEST_RELEASES_PATH_DNX_AWS_CLI,
    headers={'Authorization': 'token ' + GITHUB_TOKEN})
release_docker_aws_v2_json_obj = json.loads(response_release_docker_aws_v2.text)
tag_name_docker_aws_v2 = release_docker_aws_v2_json_obj.get('tag_name').split('-')[0]

print('Upstream version: %s' % tag_name_aws_cli)
print('DNX docker-aws-v2 version: %s' % tag_name_docker_aws_v2)

if semver.compare(tag_name_aws_cli, tag_name_docker_aws_v2) != 1:
    print('Nothing to do, the upstream is in the same version or lower version.')
    sys.exit()

# Generate Dockerfile template with new upstream version
root = os.path.dirname(os.path.abspath(__file__))
templates_dir = os.path.join(root, 'templates')
env = Environment( loader = FileSystemLoader(templates_dir) )
template = env.get_template('Dockerfile.j2')
filename = os.path.join(root, 'Dockerfile')

with open(filename, 'w') as fh:
    fh.write(template.render(
        tag_name_aws_cli = tag_name_aws_cli
    ))

# Add and push changes to github repo
with open('Dockerfile') as f:
    docker_file = f.read()

# Connect to GitHub API and push the changes.
github = github3.login(token=GITHUB_TOKEN)
repository = github.repository_with_id(GITHUB_REPOSITORY_ID)

github_dockerfile = repository.file_contents('/Dockerfile', ref=DEFAULT_BRANCH)

pushed_index_change = github_dockerfile.update(
    'Bump aws-cli version to v%s' % tag_name_aws_cli,
    docker_file.encode('utf-8'),
    branch=DEFAULT_BRANCH
)

print('Pushed commit {} to {} branch:\n    {}'.format(
    pushed_index_change['commit'].sha,
    DEFAULT_BRANCH,
    pushed_index_change['commit'].message,
))

#Create new release
data = {
    'name': '%s-dnx1' % tag_name_aws_cli,
    'tag_name': '%s-dnx1' % tag_name_aws_cli,
    'body': '- Bump aws-cli version to v%s.' % tag_name_aws_cli
}

headers = {
    'Authorization': 'token %s' % GITHUB_TOKEN,
    'Accept': 'application/vnd.github.v3+json'
}

response_new_release = requests.post(
    'https://api.github.com/repos/DNXLabs/docker-aws-v2/releases',
    data=json.dumps(data),
    headers=headers
)