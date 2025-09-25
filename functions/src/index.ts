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
      features: [{type: "LABEL_DETECTION", maxResults: 10}],
    });

    const labels = (res.labelAnnotations || [])
      .map((l) => l.description)
      .filter((v): v is string => !!v);

    const tags = Array.from(new Set(labels.map((t) => t.toLowerCase())));
    return {tags};
  } catch (err) {
    console.error("Vision error", err);
    throw new HttpsError("internal", "Vision API failed");
  }
});
