const {onRequest} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");

const naverClientSecret = defineSecret("NAVER_CLIENT_SECRET");
const kakaoClientSecret = defineSecret("KAKAO_CLIENT_SECRET");
const naverClientId = "BzaebjNVvZntEFUervTF";
const kakaoRestApiKey = "97b4011bc63ddb77be006cdd8eae6814";
const allowedRedirectUris = new Set([
  "https://sumin-coder.github.io/school_project/",
  "http://localhost:5173/",
]);

exports.naverOAuth = onRequest(
    {
      region: "us-central1",
      cors: [
        "https://sumin-coder.github.io",
        "http://localhost:5173",
      ],
      secrets: [naverClientSecret],
    },
    async (req, res) => {
      if (req.method !== "POST") {
        res.status(405).json({error: "METHOD_NOT_ALLOWED"});
        return;
      }

      const {code, state, redirectUri} = req.body || {};
      if (
        typeof code !== "string" ||
        typeof state !== "string" ||
        !state.startsWith("naver_") ||
        !allowedRedirectUris.has(redirectUri)
      ) {
        res.status(400).json({error: "INVALID_OAUTH_REQUEST"});
        return;
      }

      try {
        const tokenUrl = new URL("https://nid.naver.com/oauth2.0/token");
        tokenUrl.search = new URLSearchParams({
          grant_type: "authorization_code",
          client_id: naverClientId,
          client_secret: naverClientSecret.value(),
          code,
          state,
        }).toString();

        const tokenResponse = await fetch(tokenUrl);
        const tokenData = await tokenResponse.json();
        if (!tokenResponse.ok || !tokenData.access_token) {
          res.status(401).json({error: "NAVER_TOKEN_EXCHANGE_FAILED"});
          return;
        }

        const profileResponse = await fetch(
            "https://openapi.naver.com/v1/nid/me",
            {headers: {Authorization: `Bearer ${tokenData.access_token}`}},
        );
        const profileData = await profileResponse.json();
        const profile = profileData.response;
        if (!profileResponse.ok || !profile?.id) {
          res.status(401).json({error: "NAVER_PROFILE_REQUEST_FAILED"});
          return;
        }

        res.status(200).json({
          id: String(profile.id),
          email: profile.email || null,
          name: profile.name || profile.nickname || null,
        });
      } catch (_) {
        res.status(502).json({error: "NAVER_AUTH_SERVICE_UNAVAILABLE"});
      }
    },
);

exports.kakaoOAuth = onRequest(
    {
      region: "us-central1",
      cors: [
        "https://sumin-coder.github.io",
        "http://localhost:5173",
      ],
      secrets: [kakaoClientSecret],
    },
    async (req, res) => {
      if (req.method !== "POST") {
        res.status(405).json({error: "METHOD_NOT_ALLOWED"});
        return;
      }

      const {code, state, redirectUri} = req.body || {};
      if (
        typeof code !== "string" ||
        typeof state !== "string" ||
        !state.startsWith("kakao_") ||
        !allowedRedirectUris.has(redirectUri)
      ) {
        res.status(400).json({error: "INVALID_OAUTH_REQUEST"});
        return;
      }

      try {
        const tokenResponse = await fetch("https://kauth.kakao.com/oauth/token", {
          method: "POST",
          headers: {
            "Content-Type": "application/x-www-form-urlencoded;charset=utf-8",
          },
          body: new URLSearchParams({
            grant_type: "authorization_code",
            client_id: kakaoRestApiKey,
            client_secret: kakaoClientSecret.value(),
            redirect_uri: redirectUri,
            code,
          }),
        });
        const tokenData = await tokenResponse.json();
        if (!tokenResponse.ok || !tokenData.access_token) {
          res.status(401).json({error: "KAKAO_TOKEN_EXCHANGE_FAILED"});
          return;
        }

        const profileResponse = await fetch(
            "https://kapi.kakao.com/v2/user/me",
            {headers: {Authorization: `Bearer ${tokenData.access_token}`}},
        );
        const profile = await profileResponse.json();
        if (!profileResponse.ok || !profile?.id) {
          res.status(401).json({error: "KAKAO_PROFILE_REQUEST_FAILED"});
          return;
        }

        res.status(200).json({
          id: String(profile.id),
          email: profile.kakao_account?.email || null,
          name: profile.kakao_account?.profile?.nickname ||
            profile.properties?.nickname || null,
        });
      } catch (_) {
        res.status(502).json({error: "KAKAO_AUTH_SERVICE_UNAVAILABLE"});
      }
    },
);
