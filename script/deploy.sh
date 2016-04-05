#!/bin/bash
set -e

if ([ "$TRAVIS_BRANCH" = "master" ] || [ ! -z "$TRAVIS_TAG" ]) && [ "$TRAVIS_PULL_REQUEST" = "false" ]; then
  echo "Deploying..."
else
  echo "Skipping deploy"
  exit 0
fi

# load ssh key
echo "Loading key..."
openssl aes-256-cbc -K $encrypted_27087ae1f4db_key -iv $encrypted_27087ae1f4db_iv -in .travis/traefik.id_rsa.enc -out ~/.ssh/traefik.id_rsa -d
eval "$(ssh-agent -s)"
chmod 600 ~/.ssh/traefik.id_rsa
ssh-add ~/.ssh/traefik.id_rsa

# download github release
echo "Downloading ghr..."
curl -LOs https://github.com/tcnksm/ghr/releases/download/pre-release/linux_amd64.zip
unzip -q linux_amd64.zip
sudo mv ghr /usr/bin/ghr
sudo chmod +x /usr/bin/ghr

# github release and tag
echo "Github release..."
ghr -t $GITHUB_TOKEN -u containous -r traefik --prerelease ${VERSION} dist/

# update docs.traefik.io
echo "Generating and updating documentation..."
mkdocs gh-deploy --clean

# update traefik-library-image repo (official Docker image)
echo "Updating traefik-library-imag repo..."
git config --global user.email "emile@vauge.com"
git config --global user.name "Emile Vauge"
git clone git@github.com:containous/traefik-library-image.git
cd traefik-library-image
./update.sh $VERSION
git add -A
echo $VERSION | git commit --file -
echo $VERSION | git tag -a $VERSION --file -
git push -q --follow-tags -u origin master

# create docker image emilevauge/traefik (compatibility)
echo "Updating docker emilevauge/traefik image..."
docker login -e $DOCKER_EMAIL -u $DOCKER_USER -p $DOCKER_PASS
docker tag containous/traefik emilevauge/traefik:latest
docker push emilevauge/traefik:latest
docker tag emilevauge/traefik:latest emilevauge/traefik:${VERSION}
docker push emilevauge/traefik:${VERSION}

cd ..
rm -Rf traefik-library-image/

echo "Deployed"