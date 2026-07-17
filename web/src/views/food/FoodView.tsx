/* Food tab: fastest possible path from "I ate something" to "it's logged". */

import { todayKey } from "../../models/dayKey";
import FoodCatalog from "./FoodCatalog";

export default function FoodView() {
  return (
    <div className="screen">
      <h1 className="screen-title">Food</h1>
      <FoodCatalog dayKey={todayKey()} />
    </div>
  );
}
