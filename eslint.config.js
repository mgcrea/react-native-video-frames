import baseConfig from "@mgcrea/eslint-config-react-native";

const config = [
  ...baseConfig,
  {
    rules: {
    },
  },
  {
    ignores: [".idea/**", "example/**", "test/**"],
  },
  {
    languageOptions: {
      parserOptions: {
        project: ["./tsconfig.node.json", "./tsconfig.json"],
        tsconfigRootDir: import.meta.dirname,
      },
    },
  },
];

export default config;
