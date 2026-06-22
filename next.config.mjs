/** @type {import('next').NextConfig} */
const apiTelemetryBase =
  process.env.NEXT_PUBLIC_YIELDSWARM_API_URL?.replace(/\/$/, "") ||
  "https://api.yieldswarm.crypto";

const nextConfig = {
  reactStrictMode: true,
  swcMinify: true,
  images: {
    remotePatterns: [
      { protocol: "https", hostname: "yieldswarm-v2.vercel.app" },
      { protocol: "https", hostname: "v2-0-bay.vercel.app" },
    ],
  },
  experimental: {
    serverComponentsExternalPackages: ["square", "@neondatabase/serverless"],
  },
  async rewrites() {
    return {
      beforeFiles: [
        { source: "/sales", destination: "/sales.html" },
        { source: "/marketplace", destination: "/marketplace.html" },
        {
          source: "/api/telemetry/:path*",
          destination: `${apiTelemetryBase}/:path*`,
        },
      ],
    };
  },
};

export default nextConfig;
