const allowedRedirectUris = new Set([
  "https://sumin-coder.github.io/school_project/",
  "http://localhost:3000/",
  "http://localhost:5173/",
]);
const allowedOrigins = new Set([...allowedRedirectUris].map((uri) => new URL(uri).origin));

export default {
  async fetch(request, env) {
    const origin = request.headers.get("Origin") || "";
    const corsHeaders = {
      "Access-Control-Allow-Origin": allowedOrigins.has(origin)
        ? origin
        : "https://sumin-coder.github.io",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
      "Vary": "Origin",
    };

    if (request.method === "OPTIONS") {
      return new Response(null, {headers: corsHeaders});
    }
    if (request.method !== "POST") {
      return json({error: "METHOD_NOT_ALLOWED"}, 405, corsHeaders);
    }

    const path = new URL(request.url).pathname;
    const provider = path.endsWith("/naverOAuth") ? "naver" :
      path.endsWith("/kakaoOAuth") ? "kakao" : null;
    if (!provider) return json({error: "NOT_FOUND"}, 404, corsHeaders);
    if (!allowedOrigins.has(origin)) {
      return json({error: "ORIGIN_NOT_ALLOWED"}, 403, corsHeaders);
    }

    try {
      const {code, state, redirectUri} = await request.json();
      if (
        typeof code !== "string" ||
        typeof state !== "string" ||
        !state.startsWith(`${provider}_`) ||
        !allowedRedirectUris.has(redirectUri)
      ) {
        return json({error: "INVALID_OAUTH_REQUEST"}, 400, corsHeaders);
      }

      const profile = provider === "naver"
        ? await getNaverProfile(code, state, redirectUri, env)
        : await getKakaoProfile(code, redirectUri, env);
      return json(profile, 200, corsHeaders);
    } catch (error) {
      return json(
        {error: error instanceof OAuthError ? error.code : "OAUTH_SERVICE_UNAVAILABLE"},
        error instanceof OAuthError ? error.status : 502,
        corsHeaders,
      );
    }
  },
};

class OAuthError extends Error {
  constructor(code, status = 401) {
    super(code);
    this.code = code;
    this.status = status;
  }
}

async function getNaverProfile(code, state, redirectUri, env) {
  const tokenUrl = new URL("https://nid.naver.com/oauth2.0/token");
  tokenUrl.search = new URLSearchParams({
    grant_type: "authorization_code",
    client_id: env.NAVER_CLIENT_ID,
    client_secret: env.NAVER_CLIENT_SECRET,
    code,
    state,
  });
  const token = await readJson(await fetch(tokenUrl));
  if (!token.access_token) throw new OAuthError("NAVER_TOKEN_EXCHANGE_FAILED");

  const result = await readJson(await fetch("https://openapi.naver.com/v1/nid/me", {
    headers: {Authorization: `Bearer ${token.access_token}`},
  }));
  const user = result.response;
  if (!user?.id) throw new OAuthError("NAVER_PROFILE_REQUEST_FAILED");
  return {
    id: String(user.id),
    email: user.email || null,
    name: user.name || user.nickname || null,
  };
}

async function getKakaoProfile(code, redirectUri, env) {
  const tokenParams = new URLSearchParams({
    grant_type: "authorization_code",
    client_id: env.KAKAO_REST_API_KEY,
    redirect_uri: redirectUri,
    code,
  });
  if (env.KAKAO_CLIENT_SECRET) tokenParams.set("client_secret", env.KAKAO_CLIENT_SECRET);
  const token = await readJson(await fetch("https://kauth.kakao.com/oauth/token", {
    method: "POST",
    headers: {"Content-Type": "application/x-www-form-urlencoded;charset=utf-8"},
    body: tokenParams,
  }));
  if (!token.access_token) throw new OAuthError("KAKAO_TOKEN_EXCHANGE_FAILED");

  const user = await readJson(await fetch("https://kapi.kakao.com/v2/user/me", {
    headers: {Authorization: `Bearer ${token.access_token}`},
  }));
  if (!user.id) throw new OAuthError("KAKAO_PROFILE_REQUEST_FAILED");
  return {
    id: String(user.id),
    email: user.kakao_account?.email || null,
    name: user.kakao_account?.profile?.nickname ||
      user.properties?.nickname || null,
  };
}

async function readJson(response) {
  const result = await response.json();
  if (!response.ok) throw new OAuthError("PROVIDER_REQUEST_FAILED");
  return result;
}

function json(body, status, headers) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {...headers, "Content-Type": "application/json; charset=utf-8"},
  });
}
