#!/bin/bash -x

echo "##################### EXECUTE: kurento_generate_js_module #####################"

rm -rf build
mkdir build && cd build
cmake .. -DGENERATE_JS_CLIENT_PROJECT=TRUE -DDISABLE_LIBRARIES_GENERATION=TRUE || {
  echo "[kurento_generate_js_module] ERROR: Command failed: cmake"
  exit 1
}

[ -d js ] || {
  echo "[kurento_generate_js_module] ERROR: Expected directory doesn't exist: $PWD/js"
  exit 1
}

JS_PROJECT_NAME="$(cat js_project_name)-js"
echo "[kurento_generate_js_module] Generated sources: $JS_PROJECT_NAME"

kurento_clone_repo.sh "$JS_PROJECT_NAME" "$GERRIT_NEWREV" || {
  echo "[kurento_generate_js_module] ERROR: Command failed: git clone $JS_PROJECT_NAME $GERRIT_NEWREV"
  exit 1
}

rm -rf "${JS_PROJECT_NAME}/*"
cp -a js/* "${JS_PROJECT_NAME}/"

echo "Commit and push changes to repo: $JS_PROJECT_NAME"

COMMIT_ID="$(git rev-parse --short HEAD)"

pushd "$JS_PROJECT_NAME"
git status
git diff-index --quiet HEAD || {
  git add --all .
  git commit -m "Generated code from ${KURENTO_PROJECT}@${COMMIT_ID}"
  git push origin master || {
    echo "Couldn't push changes to repo: $JS_PROJECT_NAME"
    exit 1
  }
}
popd

# Only create a tag if the deployment process was successful
# Commented out because this is currently being done in the main kms-{core,elements,filters} job.
# Uncomment when this is sorted out and we know WHEN we want to create tags.
# kurento_check_version.sh true || {
#   echo "[kurento_generate_js_module] ERROR: Command failed: kurento_check_version (tagging enabled)"
#   exit 1
# }
