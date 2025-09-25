/* eslint-disable max-len, object-curly-spacing, comma-spacing, eol-last */
import {ImageAnnotatorClient} from "@google-cloud/vision";
import {setGlobalOptions} from "firebase-functions/v2/options";
import {onCall, HttpsError} from "firebase-functions/v2/https";

setGlobalOptions({region: "us-central1", timeoutSeconds: 60, memory: "512MiB"});

const visionClient = new ImageAnnotatorClient();

export const analyzeClothing = onCall(async (request) => {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError("unauthenticated", "Auth required");
  }

  const data = request.data as {contentBase64?: string; filename?: string};
  const contentBase64 = data?.contentBase64;
  if (!contentBase64) {
    throw new HttpsError("invalid-argument", "Missing image");
  }

  try {
    const [res] = await visionClient.annotateImage({
      image: {content: Buffer.from(contentBase64, "base64")},
      features: [
        {type: "LABEL_DETECTION", maxResults: 20},
        {type: "IMAGE_PROPERTIES", maxResults: 1},
      ],
    });

    const ALLOWLIST = new Set<string>([
      "clothing","apparel","garment","fashion","textile","fabric","outerwear","underwear","sportswear","streetwear",
      "shirt","t-shirt","tee","polo","blouse","top","tank top",
      "dress","gown","skirt",
      "pants","trousers","jeans","denim","shorts","leggings","sweatpants",
      "jacket","coat","hoodie","sweatshirt","cardigan","blazer","parka","windbreaker",
      "sweater","jumper",
      "sneakers","shoes","boots","sandals","heels","flip-flops","slippers",
      "hat","cap","beanie","bucket hat","beret","visor",
      "scarf","gloves","socks","belt","tie",
      "bag","handbag","backpack","tote","wallet",
      "pattern","plaid","striped","stripe","floral","polka dot","graphic","logo","solid",
      "vintage","casual","formal","athletic","sport","street","retro","minimalist","boho","chic","classic","oversized","slim fit","regular fit",
    ]);

    const BLACKLIST = new Set<string>([
      "beard","hair","facial hair","mustache","moustache","eyebrow","eyelash","shoulder","arm","hand","face","forehead",
      "person","man","woman","boy","girl","adult","people","human","portrait","skin",
    ]);

    const labels = (res.labelAnnotations || [])
      .filter((l) => (l.score ?? 0) >= 0.7)
      .map((l) => (l.description || "").toLowerCase())
      .filter((t) => t && !BLACKLIST.has(t))
      .filter((t) => ALLOWLIST.has(t) || Array.from(ALLOWLIST).some((a) => t.includes(a)));

    const colors = (res.imagePropertiesAnnotation?.dominantColors?.colors || [])
      .sort((a, b) => (b.pixelFraction ?? 0) - (a.pixelFraction ?? 0))
      .slice(0, 2)
      .flatMap((c) => {
        const r = Math.round(c.color?.red ?? 0);
        const g = Math.round(c.color?.green ?? 0);
        const b = Math.round(c.color?.blue ?? 0);
        const brightness = 0.2126 * r + 0.7152 * g + 0.0722 * b;
        const isDark = brightness < 90;
        if (r > 200 && g > 200 && b > 200) return ["white"];
        if (r < 50 && g < 50 && b < 50) return ["black"];
        const primaryTuple = ([
          [r, "red"],
          [g, "green"],
          [b, "blue"],
        ] as Array<[number, string]>).sort((x, y) => (y[0] as number) - (x[0] as number))[0];
        const primary = primaryTuple[1];
        if (primary === "red" && g > 180 && b < 120) return ["yellow"];
        if (primary === "red" && b > 180 && g < 120) return ["magenta"];
        if (primary === "green" && b > 160) return ["cyan"];
        return [isDark ? `dark ${primary}` : primary];
      });

    const tags = Array.from(new Set([...labels, ...colors])).filter(Boolean);
    return {tags};
  } catch (err) {
    console.error("Vision error", err);
    throw new HttpsError("internal", "Vision API failed");
  }
});
