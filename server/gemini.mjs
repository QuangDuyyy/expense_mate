export function generationSettings(model, image) {
  const settings = {maxOutputTokens: image ? 16384 : 4096};
  if (/^gemini-[34](?:[.-])/.test(model)) settings.thinkingConfig={thinkingLevel:'low'};
  else if (/^gemini-2\.5-flash(?:-|$)/.test(model)) settings.thinkingConfig={thinkingBudget:0};
  else settings.temperature=0.1;
  return settings;
}
export function parseGeminiResponse(result) {
  const fail=code=>{const e=new Error(code);e.aiCode=code;throw e;};
  if (result?.promptFeedback?.blockReason) fail('AI_BLOCKED');
  const candidate=result?.candidates?.[0];
  if(candidate?.finishReason==='MAX_TOKENS')fail('AI_TRUNCATED');
  if(candidate?.finishReason&&candidate.finishReason!=='STOP')fail('AI_BLOCKED');
  const parts=candidate?.content?.parts;
  if(!Array.isArray(parts))fail('AI_EMPTY_RESPONSE');
  const text=parts.filter(p=>p&&!p.thought&&typeof p.text==='string').map(p=>p.text).join('').trim();
  if(!text)fail('AI_EMPTY_RESPONSE');
  const clean=text.replace(/^```(?:json)?\s*([\s\S]*?)\s*```$/,'$1');
  try{return JSON.parse(clean);}catch{fail('AI_INVALID_RESPONSE');}
}
export async function upstreamCode(response) {
  if(response.status===400){
    // Inspect only structured reason IDs; never emit the upstream body or key.
    try {const body=await response.json();const details=body?.error?.details;
      if(Array.isArray(details)&&details.some(d=>['API_KEY_INVALID','API_KEY_EXPIRED'].includes(d.reason)))return 'AI_KEY_INVALID';
    }catch{/* Not a structured Google error. */}
    return 'AI_REQUEST_REJECTED';
  }
  return ({401:'AI_KEY_INVALID',403:'AI_KEY_DENIED',404:'AI_MODEL_UNAVAILABLE',429:'AI_QUOTA',500:'AI_BUSY',502:'AI_BUSY',503:'AI_BUSY',504:'AI_TIMEOUT'})[response.status]??'AI_UNAVAILABLE';
}
