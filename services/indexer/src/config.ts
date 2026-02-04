import path from "node:path";

export type IndexerMode = "sync" | "follow";

export const config = {
  rpcUrl: process.env.RPC_URL ?? "http://127.0.0.1:8545",
  dbPath:
    process.env.INDEXER_DB_PATH ??
    path.resolve(process.cwd(), "services/indexer/data/indexer.sqlite"),
  mode: (process.env.INDEXER_MODE ?? "sync") as IndexerMode,
  fromBlock: Number(process.env.INDEXER_FROM_BLOCK ?? "0"),
  port: Number(process.env.INDEXER_PORT ?? "4000"),
};
