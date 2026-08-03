import { useMemo, useState } from "react";
import { AnimatePresence, motion } from "framer-motion";
import type { CatalogItem, Subscription } from "@/lib/types";
import { ONBOARDING_PICKS } from "./data";
import { SpaceBackground } from "@/components/ui/SpaceBackground";
import { WelcomeStep } from "./steps/WelcomeStep";
import { StatStep } from "./steps/StatStep";
import { PickStep } from "./steps/PickStep";
import { RevealStep } from "./steps/RevealStep";
import "./onboarding.css";

/** New records built from onboarding picks, ready to hand to store.add(). */
export type NewSub = Omit<Subscription, "id" | "createdAt">;

interface Props {
  currency: string;
  /** Persist the chosen subscriptions and finish onboarding. */
  onFinish: (picks: NewSub[]) => void;
}

type StepKey = "welcome" | "stat" | "pick" | "reveal";
const ORDER: StepKey[] = ["welcome", "stat", "pick", "reveal"];

/** Full-screen, multi-step onboarding. Screens slide horizontally with a
 *  spring; a hairline progress bar tracks position. The whole flow is
 *  swipe-forward in feel and mirrors the reference app's cadence. */
export function Onboarding({ currency, onFinish }: Props) {
  const [step, setStep] = useState<StepKey>("welcome");
  const [dir, setDir] = useState(1);
  const [chosen, setChosen] = useState<CatalogItem[]>([]);

  const index = ORDER.indexOf(step);

  const go = (next: StepKey) => {
    setDir(ORDER.indexOf(next) > index ? 1 : -1);
    setStep(next);
  };

  const picks: NewSub[] = useMemo(
    () => chosen.map((c) => toSub(c, currency)),
    [chosen, currency]
  );

  const finish = () => onFinish(picks);

  return (
    <div className="ob">
      <SpaceBackground />

      {/* progress rail */}
      <div className="ob__rail" aria-hidden>
        <motion.div
          className="ob__rail-fill"
          animate={{ width: `${((index + 1) / ORDER.length) * 100}%` }}
          transition={{ type: "spring", stiffness: 220, damping: 30 }}
        />
      </div>

      <AnimatePresence initial={false} mode="popLayout" custom={dir}>
        <motion.div
          key={step}
          className="ob__page no-scrollbar"
          custom={dir}
          variants={PAGE}
          initial="enter"
          animate="center"
          exit="exit"
          transition={{ type: "spring", stiffness: 260, damping: 30, mass: 0.9 }}
        >
          {step === "welcome" && <WelcomeStep onNext={() => go("stat")} />}
          {step === "stat" && (
            <StatStep onNext={() => go("pick")} onBack={() => go("welcome")} />
          )}
          {step === "pick" && (
            <PickStep
              currency={currency}
              options={ONBOARDING_PICKS}
              chosen={chosen}
              onChange={setChosen}
              onNext={() => (chosen.length ? go("reveal") : finish())}
              onSkip={finish}
            />
          )}
          {step === "reveal" && (
            <RevealStep currency={currency} picks={picks} onFinish={finish} />
          )}
        </motion.div>
      </AnimatePresence>
    </div>
  );
}

const PAGE = {
  enter: (dir: number) => ({ opacity: 0, x: dir > 0 ? 64 : -64 }),
  center: { opacity: 1, x: 0 },
  exit: (dir: number) => ({ opacity: 0, x: dir > 0 ? -64 : 64 }),
};

/** Build a full expense record from a catalog pick. Anchors billing one
 *  month out so the first upcoming renewal reads naturally. */
function toSub(c: CatalogItem, currency: string): NewSub {
  const anchor = new Date();
  anchor.setMonth(anchor.getMonth() + 1);
  return {
    name: c.name,
    color: c.color,
    mark: c.mark,
    amount: c.amount,
    currency,
    cycle: "monthly",
    category: c.category,
    list: "Personal",
    flow: c.flow ?? "expense",
    paymentMethod: "",
    anchorDate: anchor.toISOString().slice(0, 10),
  };
}
