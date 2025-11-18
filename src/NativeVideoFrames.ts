import type { TurboModule } from "react-native";
import { TurboModuleRegistry } from "react-native";

export type ExtractFramesOptions = {
  width?: number;
  height?: number;
};

// eslint-disable-next-line @typescript-eslint/consistent-type-definitions
export interface Spec extends TurboModule {
  extractFrames(videoPath: string, times: number[], options?: ExtractFramesOptions): Promise<string[]>;
}

export default TurboModuleRegistry.getEnforcing<Spec>("NativeVideoFramesModule");
