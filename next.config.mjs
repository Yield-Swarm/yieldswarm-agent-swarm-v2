/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  experimental: {
    serverComponentsExternalPackages: ["square", "@neondatabase/serverless"],
  },
  async rewrites() {
    return {
      beforeFiles: [
        { source: "/sales", destination: "/sales.html" },
        { source: "/marketplace", destination: "/marketplace.html" },
        { source: "/command-center", destination: "/command-center.html" },
      ],
    };
  },
};

export default nextConfig;
