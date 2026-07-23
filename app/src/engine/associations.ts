// The Association (♅) dimension's data source on the web: precomputed
// semantic neighbors, dumped on a Mac from Apple's NLEmbedding by
// tools/assoc-dump and shipped as data (`word|n1 n2 n3 …` per line).
// The Swift app computes the same thing live; the closure shape handed to
// ConnectionWeb is identical in both.
import type { AssociationsProvider } from "./connections";

export class AssociationIndex {
  private readonly neighbors: Map<string, string[]>;

  private constructor(neighbors: Map<string, string[]>) {
    this.neighbors = neighbors;
  }

  static fromText(text: string): AssociationIndex {
    const map = new Map<string, string[]>();
    for (const line of text.split("\n")) {
      if (line.length === 0) continue;
      const [word, rest] = line.split("|");
      if (!word || !rest) continue;
      map.set(word, rest.split(" ").filter((n) => n.length > 0));
    }
    return new AssociationIndex(map);
  }

  get count(): number {
    return this.neighbors.size;
  }

  of(word: string, cap: number): string[] {
    return (this.neighbors.get(word) ?? []).slice(0, cap);
  }

  /** The closure ConnectionWeb expects. */
  get provider(): AssociationsProvider {
    return (word, cap) => this.of(word, cap);
  }
}
