import type { TurboModule } from "react-native";
import { TurboModuleRegistry } from "react-native";

// eslint-disable-next-line @typescript-eslint/consistent-type-definitions
export interface Spec extends TurboModule {
  add(a: number, b: number): number;
}

export default TurboModuleRegistry.getEnforcing<Spec>("NativeVideoFramesModule");
