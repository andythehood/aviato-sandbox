module.exports = {
  root: true,
  parser: '@typescript-eslint/parser',
  parserOptions: {
    project: ['./web/*/tsconfig.json', './servers/*/tsconfig.json'], // or wherever your tsconfigs are
    tsconfigRootDir: __dirname,
  },
  extends: ['eslint:recommended', 'plugin:@typescript-eslint/recommended'],
};