import { CipherType } from "@bitwarden/sdk-internal";

import { InlineMenuCipherData } from "../../../../background/abstractions/overlay.background";

import {
  filterInlineMenuCiphers,
  normalizeForInlineMenuFilter,
} from "./filter-inline-menu-ciphers";

function createCipher(overrides: Partial<InlineMenuCipherData> = {}): InlineMenuCipherData {
  return {
    id: "cipher-id",
    name: "Example",
    type: CipherType.Login,
    reprompt: 0,
    favorite: false,
    icon: { imageEnabled: false, icon: "bwi-globe" },
    login: { username: "user@example.com", passkey: null },
    ...overrides,
  } as InlineMenuCipherData;
}

const ciphers: InlineMenuCipherData[] = [
  createCipher({ id: "1", name: "GitHub", login: { username: "octocat", passkey: null } }),
  createCipher({ id: "2", name: "GitLab", login: { username: "tanuki", passkey: null } }),
  createCipher({ id: "3", name: "José Café", login: { username: "jose", passkey: null } }),
  createCipher({ id: "4", name: "Bank", login: { username: "GITHUB-BACKUP", passkey: null } }),
];

const idsOf = (list: InlineMenuCipherData[]) => list.map((cipher) => cipher.id);

describe("normalizeForInlineMenuFilter", () => {
  it("lowercases the value", () => {
    expect(normalizeForInlineMenuFilter("GitHub")).toBe("github");
  });

  it("strips diacritics", () => {
    expect(normalizeForInlineMenuFilter("José Café")).toBe("jose cafe");
    expect(normalizeForInlineMenuFilter("Ação")).toBe("acao");
  });

  it("returns an empty string for absent values", () => {
    expect(normalizeForInlineMenuFilter(undefined)).toBe("");
    expect(normalizeForInlineMenuFilter(null)).toBe("");
    expect(normalizeForInlineMenuFilter("")).toBe("");
  });
});

describe("filterInlineMenuCiphers", () => {
  describe("empty queries", () => {
    it.each([undefined, null, "", "   "])("returns the original list for %p", (query) => {
      const result = filterInlineMenuCiphers(ciphers, query);

      expect(result).toBe(ciphers);
      expect(idsOf(result)).toEqual(["1", "2", "3", "4"]);
    });

    it("returns the original list when there are no ciphers", () => {
      const empty: InlineMenuCipherData[] = [];

      expect(filterInlineMenuCiphers(empty, "anything")).toBe(empty);
    });
  });

  describe("invariants", () => {
    it.each(["git", "o", "z", "GITHUB", "jose", ".*"])(
      "returns a subset of the input for query %p",
      (query) => {
        const result = filterInlineMenuCiphers(ciphers, query);

        expect(result.length).toBeLessThanOrEqual(ciphers.length);
        result.forEach((cipher) => expect(ciphers).toContain(cipher));
      },
    );

    it("preserves the order the upstream produced", () => {
      const reversed = [...ciphers].reverse();

      expect(idsOf(filterInlineMenuCiphers(reversed, "git"))).toEqual(["4", "2", "1"]);
    });

    it("does not mutate the input", () => {
      const input = [...ciphers];

      filterInlineMenuCiphers(input, "git");

      expect(idsOf(input)).toEqual(["1", "2", "3", "4"]);
    });
  });

  describe("matching", () => {
    it("matches on the cipher name", () => {
      expect(idsOf(filterInlineMenuCiphers(ciphers, "lab"))).toEqual(["2"]);
    });

    it("matches on the login username", () => {
      expect(idsOf(filterInlineMenuCiphers(ciphers, "tanuki"))).toEqual(["2"]);
    });

    it("matches name and username in a single pass", () => {
      expect(idsOf(filterInlineMenuCiphers(ciphers, "github"))).toEqual(["1", "4"]);
    });

    it("ignores case", () => {
      expect(idsOf(filterInlineMenuCiphers(ciphers, "GiThUb"))).toEqual(["1", "4"]);
    });

    it("ignores diacritics in both the query and the data", () => {
      expect(idsOf(filterInlineMenuCiphers(ciphers, "jose cafe"))).toEqual(["3"]);
      expect(idsOf(filterInlineMenuCiphers(ciphers, "José"))).toEqual(["3"]);
    });

    it("returns an empty list when nothing matches", () => {
      expect(filterInlineMenuCiphers(ciphers, "nonexistent")).toEqual([]);
    });
  });

  describe("regex metacharacters are literal text", () => {
    const withMetacharacters = [
      createCipher({ id: "plain", name: "Plain", login: { username: "plain", passkey: null } }),
      createCipher({ id: "literal", name: "a.*b", login: { username: "x", passkey: null } }),
      createCipher({ id: "nested", name: "(a+)+", login: { username: "y", passkey: null } }),
    ];

    it("does not treat .* as a wildcard", () => {
      expect(idsOf(filterInlineMenuCiphers(withMetacharacters, ".*"))).toEqual(["literal"]);
    });

    it("matches a literal .* substring", () => {
      expect(idsOf(filterInlineMenuCiphers(withMetacharacters, "a.*b"))).toEqual(["literal"]);
    });

    it("does not treat (a+)+ as a pattern", () => {
      expect(idsOf(filterInlineMenuCiphers(withMetacharacters, "(a+)+"))).toEqual(["nested"]);
    });

    it.each(["[", "(", "\\", "^", "$", "?", "+"])(
      "does not throw on the unbalanced metacharacter %p",
      (query) => {
        expect(() => filterInlineMenuCiphers(withMetacharacters, query)).not.toThrow();
      },
    );
  });

  describe("incomplete ciphers", () => {
    it("handles a missing login object", () => {
      const list = [createCipher({ id: "no-login", name: "Nameless login", login: undefined })];

      expect(idsOf(filterInlineMenuCiphers(list, "nameless"))).toEqual(["no-login"]);
      expect(filterInlineMenuCiphers(list, "user")).toEqual([]);
    });

    it("handles an absent username", () => {
      const list = [createCipher({ id: "no-username", name: "Card", login: { passkey: null } })];

      expect(idsOf(filterInlineMenuCiphers(list, "card"))).toEqual(["no-username"]);
      expect(filterInlineMenuCiphers(list, "anything")).toEqual([]);
    });

    it("handles an empty name", () => {
      const list = [
        createCipher({ id: "no-name", name: "", login: { username: "solo", passkey: null } }),
      ];

      expect(idsOf(filterInlineMenuCiphers(list, "solo"))).toEqual(["no-name"]);
      expect(filterInlineMenuCiphers(list, "x")).toEqual([]);
    });
  });
});
