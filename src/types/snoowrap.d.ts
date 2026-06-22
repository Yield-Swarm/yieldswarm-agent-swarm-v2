declare module "snoowrap" {
  export default class Snoowrap {
    constructor(config: {
      userAgent: string;
      clientId: string;
      clientSecret: string;
      refreshToken: string;
    });
    getSubreddit(name: string): {
      submitSelfpost(opts: { title: string; text: string }): Promise<{
        id: string;
        url: string;
        name: string;
        permalink: string;
      }>;
    };
  }
}
