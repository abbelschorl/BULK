import { useState } from "react";
import TodayView from "./views/today/TodayView";
import FoodView from "./views/food/FoodView";
import ProgressScreen from "./views/progress/ProgressScreen";
import SettingsView from "./views/settings/SettingsView";
import { SunIcon, SearchIcon, ChartIcon, GearIcon } from "./components/icons";

const tabs = [
  { id: "today", label: "Today", icon: SunIcon, view: TodayView },
  { id: "food", label: "Food", icon: SearchIcon, view: FoodView },
  { id: "progress", label: "Progress", icon: ChartIcon, view: ProgressScreen },
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
            <Icon size={25} />
          </button>
        ))}
      </nav>
    </>
  );
}
