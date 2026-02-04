import { useEffect } from "react";
import { useRouter } from "next/router";

export default function HomePage() {
  const router = useRouter();
  useEffect(() => {
    void router.replace("/agents");
  }, [router]);

  return <div className="container">Redirecting to agents…</div>;
}
