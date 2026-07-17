import { useState } from "react";
import TodayView from "./views/today/TodayView";
import FoodView from "./views/food/FoodView";
import ProgressScreen from "./views/progress/ProgressScreen";
import SupplementsView from "./views/supplements/SupplementsView";
import SettingsView from "./views/settings/SettingsView";
import { SunIcon, SearchIcon, ChartIcon, PillIcon, GearIcon } from "./components/icons";

const tabs = [
  { id: "today", label: "Today", icon: SunIcon, view: TodayView },
  { id: "food", label: "Food", icon: SearchIcon, view: FoodView },
  { id: "progress", label: "Progress", icon: ChartIcon, view: ProgressScreen },
  { id: "supplements", label: "Supplements", icon: PillIcon, view: SupplementsView },
  { id: "settings", label: "Settings", icon: GearIcon, view: SettingsView },
] as const;

type TabId = (typeof tabs)[number]["id"];

export default function App() {
  const [active, setActive] = useState<TabId>("today");
  const ActiveView = tabs.find((t) => t.id === active)!.view;

  return (
    <>
      <ActiveView />
      <nav className="tabbar">
        {tabs.map(({ id, label, icon: Icon }) => (
          <button
            key={id}
            className={id === active ? "active" : ""}
            onClick={() => setActive(id)}
            aria-label={label}
          >
            <Icon />
            {label}
          </button>
        ))}
      </nav>
    </>
  );
}
