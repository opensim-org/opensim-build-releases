
## Set up ssh for sourceforge.
# Decrypt the private key stored in the repository to the tmp dir.
openssl aes-256-cbc -K $encrypted_d246489684fa_key -iv $encrypted_d246489684fa_iv -in .deploy_myosin_sourceforge_rsa.enc -out /tmp/deploy_myosin_sourceforge_rsa -d
# Start the ssh agent.
eval "$(ssh-agent -s)"
# Register this private key with this client (the travis machine).
chmod 600 /tmp/deploy_myosin_sourceforge_rsa
ssh-add /tmp/deploy_myosin_sourceforge_rsa


## Upload to sourceforge.net/projects/myosin
# See https://docs.travis-ci.com/user/deployment/custom/
# '--archive' preserves symlinks.
rsync --archive --compress --verbose $1 opensim-bot@frs.sourceforge.net:/home/frs/project/myosin/opensim-build-releases
