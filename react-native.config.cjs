module.exports = {
  dependency: {
    platforms: {
      android: {
        componentDescriptors: [],
        // Point to codegen-generated JNI files
        cmakeListsPath: 'generated/jni/CMakeLists.txt',
      },
      ios: {},
    },
  },
};
