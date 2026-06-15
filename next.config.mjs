/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  // Square + some web3 deps ship optional native/server-only modules; keep them external on the server.
  experimental: {
    serverComponentsExternalPackages: ["square"],
  },
};

export default nextConfig;
