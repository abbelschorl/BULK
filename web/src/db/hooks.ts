/* Live query hook: re-runs an async repo query whenever any repo write
   happens, plus when the caller's deps change. */

import { useEffect, useState } from "react";
import { dataVersion, subscribe } from "./repo";

export function useQuery<T>(query: () => Promise<T>, deps: unknown[]): T | undefined {
  const [result, setResult] = useState<T>();
  const [tick, setTick] = useState(dataVersion());

  useEffect(() => subscribe(() => setTick(dataVersion())), []);

  useEffect(() => {
    let cancelled = false;
    query().then((value) => {
      if (!cancelled) setResult(value);
    });
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [tick, ...deps]);

  return result;
}
