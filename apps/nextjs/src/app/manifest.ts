import type { MetadataRoute } from "next";

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "Khulanode Services Dashboard",
    short_name: "Khulanode Services Dashboard",
    description: "Your dashboard for managing your server.",
    start_url: "/",
    display: "standalone",
    background_color: "#fff",
    theme_color: "#239CF4",
    icons: [
      {
        src: "/images/pwa/khulanode-192.png",
        sizes: "192x192",
        type: "image/png",
        purpose: "any",
      },
      {
        src: "/images/pwa/khulanode-192.png",
        sizes: "192x192",
        type: "image/png",
        purpose: "maskable",
      },
      {
        src: "/images/pwa/khulanode-512.png",
        sizes: "512x512",
        type: "image/png",
        purpose: "any",
      },
      {
        src: "/images/pwa/khulanode-512.png",
        sizes: "512x512",
        type: "image/png",
        purpose: "maskable",
      },
    ],
  };
}
