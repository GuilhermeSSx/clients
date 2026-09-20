import { InlineMenuCipherData } from "../../../../background/abstractions/overlay.background";

/**
 * Matches the combining marks that `String.prototype.normalize("NFD")` splits
 * diacritics into. This is a fixed pattern over a known Unicode range; it is
 * never built from user input.
 */
const COMBINING_MARKS = /[̀-ͯ]/g;

/**
 * Normalizes a value so that comparisons ignore case and diacritics, letting
 * "jose" match "José".
 *
 * @param value - The value to normalize.
 * @returns The normalized value, or an empty string when there is nothing to normalize.
 */
export function normalizeForInlineMenuFilter(value: string | undefined | null): string {
  if (!value) {
    return "";
  }

  return value.normalize("NFD").replace(COMBINING_MARKS, "").toLowerCase();
}

/**
 * Narrows the ciphers the background has already handed to the inline menu down
 * to the ones matching the query. This never requests additional ciphers and
 * never searches beyond the list it was given.
 *
 * A cipher matches when the query appears in its name or in its login username.
 * Matching is a plain substring check on the normalized value, so regex
 * metacharacters in the query are treated as literal text.
 *
 * The result preserves the order of the input, as the upstream ordering is
 * meaningful, and an empty query returns the input untouched.
 *
 * @param ciphers - The ciphers the inline menu currently holds.
 * @param query - The text typed into the form field.
 * @returns The matching ciphers, in their original order.
 */
export function filterInlineMenuCiphers(
  ciphers: InlineMenuCipherData[],
  query: string | undefined | null,
): InlineMenuCipherData[] {
  const normalizedQuery = normalizeForInlineMenuFilter(query).trim();
  if (!normalizedQuery || !ciphers?.length) {
    return ciphers;
  }

  return ciphers.filter((cipher) => cipherMatchesQuery(cipher, normalizedQuery));
}

/**
 * Determines whether a single cipher matches an already normalized query.
 *
 * @param cipher - The cipher to test.
 * @param normalizedQuery - The normalized, non-empty query.
 * @returns Whether the cipher's name or login username contains the query.
 */
function cipherMatchesQuery(cipher: InlineMenuCipherData, normalizedQuery: string): boolean {
  if (normalizeForInlineMenuFilter(cipher?.name).includes(normalizedQuery)) {
    return true;
  }

  return normalizeForInlineMenuFilter(cipher?.login?.username).includes(normalizedQuery);
}
