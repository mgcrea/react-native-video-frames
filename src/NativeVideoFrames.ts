import type { TurboModule } from "react-native";
import { TurboModuleRegistry } from "react-native";

// eslint-disable-next-line @typescript-eslint/consistent-type-definitions
export interface Spec extends TurboModule {
  extractFrames(videoPath: string, times: number[]): Promise<string[]>;
}

export default TurboModuleRegistry.getEnforcing<Spec>("NativeVideoFramesModule");
