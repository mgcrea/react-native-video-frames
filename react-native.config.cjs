/* eslint-env node */
module.exports = {
  dependency: {
    platforms: {
      android: {
        // Pure Kotlin TurboModule - no CMake/C++ needed
        cmakeListsPath: null,
      },
      ios: {},
    },
  },
};
