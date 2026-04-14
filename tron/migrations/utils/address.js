function getTronWebInstance(tronWebArg) {
  if (tronWebArg) return tronWebArg;
  if (typeof globalThis !== "undefined" && globalThis.tronWeb) return globalThis.tronWeb;
  throw new Error("[tron] tronWeb instance is not available");
}

function toTronHexAddress(value, tronWebArg) {
  const tw = getTronWebInstance(tronWebArg);
  if (!value) return "";
  if (/^41[0-9a-fA-F]{40}$/.test(value)) return value;
  if (/^0x[0-9a-fA-F]{40}$/.test(value)) return `41${value.slice(2)}`;
  if (tw.isAddress(value)) {
    const hex = tw.address.toHex(value);
    return hex.startsWith("0x") ? hex.slice(2) : hex;
  }
  throw new Error(`[tron] invalid address: ${value}`);
}

function tryToTronHexAddress(value, tronWebArg) {
  try {
    return toTronHexAddress(value, tronWebArg);
  } catch {
    return "";
  }
}

function toEvmAddress(value, tronWebArg) {
  const tronHex = toTronHexAddress(value, tronWebArg);
  return `0x${tronHex.slice(2)}`;
}

function toTronBase58Address(value, tronWebArg) {
  const tw = getTronWebInstance(tronWebArg);
  const tronHex = toTronHexAddress(value, tw);
  return tw.address.fromHex(tronHex);
}

function normalizeOutputAddresses(value, tronWebArg) {
  const tw = getTronWebInstance(tronWebArg);
  if (Array.isArray(value)) return value.map((v) => normalizeOutputAddresses(v, tw));
  if (!value || typeof value !== "object") {
    if (typeof value === "string") {
      try {
        return toTronBase58Address(value, tw);
      } catch {
        return value;
      }
    }
    return value;
  }
  return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, normalizeOutputAddresses(v, tw)]));
}

module.exports = {
  toTronHexAddress,
  tryToTronHexAddress,
  toEvmAddress,
  toTronBase58Address,
  normalizeOutputAddresses,
};
