/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  // Termux/Android: set swcMinify false + use `npm run termux:dev` (avoids @next/swc-android-arm64)
  swcMinify: process.env.NEXT_DISABLE_SWC === '1' ? false : true,
  experimental: {
    serverComponentsExternalPackages: ["square", "@neondatabase/serverless"],
  },
  async rewrites() {
    return {
      beforeFiles: [
        { source: "/sales", destination: "/sales.html" },
        { source: "/marketplace", destination: "/marketplace.html" },
      ],
    };
  },
};

export default nextConfig;
