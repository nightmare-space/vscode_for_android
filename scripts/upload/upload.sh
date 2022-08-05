LOCAL_DIR=$(
    cd $(dirname $0)
    pwd
)
PROJECT_DIR=$LOCAL_DIR/../..
source $LOCAL_DIR/../properties.sh
echo $PROJECT_DIR
rsync -v $PROJECT_DIR/build/app/outputs/flutter-apk/app-release.apk $TARGET_PATH/$APP_NAME'_'$VERSION'_'Android_arm64.apk
