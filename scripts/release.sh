#!/usr/bin/env bash

if [[ -z $CODEBERG_KEY ]]; then
	echo "cant upload a build if no api key is specified"
	exit 1
fi;

TARGETS=("x86_64-linux-musl" "aarch64-macos" "x86_64-windows")
BASE="https://codeberg.org/api/v1/repos/lung/revo"
OWNER="lung"
REPO="revo"

TAG=$(git tag)
if [[ -z $TAG ]]; then
	echo "!!! no git tags found! please create one: git tag v1.0.0"
	exit 1
fi

echo ">>> making a release for $TAG"

echo "... building"
zig build release

echo "... collecting release artifacts"
ARTIFACTS=()
for f in ./zig-out/bin/revo-*; do
	ARTIFACTS+=$f
	echo "@ $f"
done

if [[ ${#ARTIFACTS[@]} -eq 0 ]]; then
	echo "!!! no artifacts found"
	exit 1
fi

echo ">>> making codeberg release"

RELEASE_RESPONSE=$(curl -s -X 'POST' \
	"$BASE/releases" \
	-H 'accept: application/json' \
	-H 'Content-Type: application/json' \
	-H "Authorization: token $CODEBERG_KEY" \
	-d "{
		\"tag_name\": \"$TAG\",
		\"name\": \"$TAG\",
		\"body\": \"$TAG released\",
		\"draft\": false,
		\"prerelease\": false
	}")

RELEASE_ID=$(echo "$RELEASE_RESPONSE" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)

if [[ -z $RELEASE_ID ]]; then
	echo "!!! failed to create release!"
	echo "$RELEASE_RESPONSE"
	exit 1
fi

echo "... uploading artifacts"

for artifact in "${ARTIFACTS[@]}"; do
	FNAME=$(basename "$artifact")
	echo "uploading $FNAME..."

	curl -s -X 'POST' \
		"$BASE/releases/$RELEASE_ID/assets?name=$FNAME" \
		-H 'accept: application/json' \
		-H "Authorization: token $CODEBERG_KEY" \
		-H 'Content-Type: application/octet-stream' \
		--data-binary "@$artifact" > /dev/null

	if [[ $? -eq 0 ]]; then
		echo "@ uploaded $FILE_NAME"
	else
		echo "!!! failed to upload $FILE_NAME"
	fi
done

echo ">>> done!"
