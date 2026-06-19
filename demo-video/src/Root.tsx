import React from "react";
import { Composition } from "remotion";
import { DriftDemo } from "./DriftDemo";
import { DriftLandingDemo } from "./DriftLandingDemo";

export const Root: React.FC = () => {
  return (
    <>
      <Composition
        id="DriftDemo"
        component={DriftDemo}
        durationInFrames={960}
        fps={30}
        width={1920}
        height={1080}
      />
      <Composition
        id="DriftLandingDemo"
        component={DriftLandingDemo}
        durationInFrames={450}
        fps={30}
        width={1280}
        height={720}
      />
    </>
  );
};
