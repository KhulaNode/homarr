import type { LogoWithTitleProps } from "./logo";
import { Logo, LogoWithTitle } from "./logo";

interface LogoProps {
  size: number;
}

export const homarrLogoPath = "/logo/khulanode-logo.png";
export const homarrPageTitle = "Khulanode Services Dashboard";

const imageOptions = {
  src: homarrLogoPath,
  alt: "Khulanode Services Dashboard logo",
  shouldUseNextImage: true,
};

export const HomarrLogo = ({ size }: LogoProps) => <Logo size={size} {...imageOptions} />;

interface CommonLogoWithTitleProps {
  size: LogoWithTitleProps["size"];
}

export const HomarrLogoWithTitle = ({ size }: CommonLogoWithTitleProps) => {
  return <LogoWithTitle size={size} title={homarrPageTitle} image={imageOptions} />;
};
