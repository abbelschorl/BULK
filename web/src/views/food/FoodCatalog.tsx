/* The shared search-and-log surface: local library instantly, public
   databases behind a short debounce, sources clearly labeled. Used as the
   Food tab and as the "Add Food" sheet from Today. */

import { useEffect, useRef, useState } from "react";
import { useQuery } from "../../db/hooks";
import { repo } from "../../db/repo";
import { useSettings } from "../../db/settings";
import type { FoodItem, MealType, NutritionValues, SavedMeal } from "../../models/types";
import { dayTotals } from "../../logic/nutrition";
import { scalePer100g } from "../../logic/nutrition";
import { localMatches, searchPublic } from "../../services/foodSearch";
import { ORIGIN_LABELS, type FoodSearchResult } from "../../services/searchResult";
import { Format } from "../../support/format";
import LogFoodSheet, { SourceBadge } from "./LogFoodSheet";
import CustomFoodEditor from "./CustomFoodEditor";
import { LogSavedMealSheet } from "./SavedMealSheets";
import { pendingFromFood, pendingFromResult, type PendingFood } from "./pendingFood";

function mealTotals(meal: SavedMeal): NutritionValues {
  return dayTotals(
    meal.components.map((c) => ({
      id: "",
      loggedAt: "",
      dayKey: "",
      mealType: "snack" as const,
      grams: c.grams,
      foodName: c.foodName,
      per100g: c.per100g,
      sourceLabel: c.sourceLabel,
    })),
  );
}

export default function FoodCatalog({
  dayKey,
  initialMeal,
  onLogged,
}: {
  dayKey: string;
  initialMeal?: MealType;
  /** Called after a food or meal is logged (sheet flow closes itself). */
  onLogged?: () => void;
}) {
  const settings = useSettings();
  const allFoods = useQuery(() => repo.allFoods(), []) ?? [];
  const savedMeals = useQuery(() => repo.allMeals(), []) ?? [];

  const [query, setQuery] = useState("");
  const [publicResults, setPublicResults] = useState<FoodSearchResult[]>([]);
  const [publicNotes, setPublicNotes] = useState<string[]>([]);
  const [isSearching, setIsSearching] = useState(false);
  const searchToken = useRef(0);

  const [pending, setPending] = useState<PendingFood | null>(null);
  const [showEditor, setShowEditor] = useState(false);
  const [mealToLog, setMealToLog] = useState<SavedMeal | null>(null);

  const trimmed = query.trim();

  useEffect(() => {
    const token = ++searchToken.current;
    setPublicResults([]);
    setPublicNotes([]);
    if (trimmed.length < 2) {
      setIsSearching(false);
      return;
    }
    setIsSearching(true);
    const timer = setTimeout(async () => {
      const { results, notes } = await searchPublic(trimmed, settings.usdaAPIKey);
      if (searchToken.current !== token) return;
      setPublicResults(results);
      setPublicNotes(notes);
      setIsSearching(false);
    }, 450);
    return () => clearTimeout(timer);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [trimmed, settings.usdaAPIKey]);

  const localResults = trimmed ? localMatches(trimmed, allFoods) : [];

  const favorites = allFoods.filter((f) => f.isFavorite);
  const recents = allFoods
    .filter((f) => f.lastLoggedAt != null)
    .sort((a, b) => (b.lastLoggedAt ?? "").localeCompare(a.lastLoggedAt ?? ""))
    .slice(0, 8);
  const myFoods = allFoods
    .filter((f) => f.source === "myFood")
    .sort((a, b) => a.name.localeCompare(b.name));

  const closeLogSheet = (didLog: boolean) => {
    setPending(null);
    if (didLog) onLogged?.();
  };

  return (
    <div className="food-catalog">
      <div className="row">
        <div className="search-bar">
          <input
            type="search"
            placeholder="Search foods"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            aria-label="Search foods"
          />
          {query && (
            <button className="search-clear" onClick={() => setQuery("")} aria-label="Clear search">
              ✕
            </button>
          )}
        </div>
      </div>

      {trimmed === "" ? (
        <>
          {favorites.length === 0 &&
            recents.length === 0 &&
            myFoods.length === 0 &&
            savedMeals.length === 0 && (
              <div className="card diary-empty">
                <div className="diary-empty-title">Your food library is empty</div>
                <div className="text-tertiary">
                  Search a food or create a custom food. Everything you log builds your personal
                  library.
                </div>
              </div>
            )}
          {favorites.length > 0 && (
            <FoodListSection title="Favorites" foods={favorites} onPick={(f) => setPending(pendingFromFood(f))} />
          )}
          {recents.length > 0 && (
            <FoodListSection title="Recent" foods={recents} onPick={(f) => setPending(pendingFromFood(f))} />
          )}
          {savedMeals.length > 0 && (
            <section>
              <div className="section-header">Saved Meals</div>
              <div className="card list-card">
                {savedMeals.map((meal) => {
                  const totals = mealTotals(meal);
                  return (
                    <button key={meal.id} className="food-row" onClick={() => setMealToLog(meal)}>
                      <span className="food-row-left">
                        <span className="food-row-name">{meal.name}</span>
                        <span className="food-row-detail">
                          {meal.components.length} foods · {Format.kcal(totals.calories)} kcal ·{" "}
                          {Format.macroGrams(totals.protein)} g protein
                        </span>
                      </span>
                      <span className="chevron-right">›</span>
                    </button>
                  );
                })}
              </div>
            </section>
          )}
          {myFoods.length > 0 && (
            <FoodListSection title="My Foods" foods={myFoods} onPick={(f) => setPending(pendingFromFood(f))} />
          )}
        </>
      ) : (
        <>
          {localResults.length > 0 && (
            <ResultsSection
              title="Your Library"
              results={localResults}
              onPick={(r) => setPending(pendingFromResult(r))}
            />
          )}
          {isSearching && (
            <div className="text-tertiary searching-note">Searching Open Food Facts and USDA…</div>
          )}
          {publicNotes.map((note) => (
            <div key={note} className="card search-note">
              {note}
            </div>
          ))}
          {publicResults.length > 0 && (
            <ResultsSection
              title="Public Databases"
              results={publicResults}
              onPick={(r) => setPending(pendingFromResult(r))}
            />
          )}
          {localResults.length === 0 && publicResults.length === 0 && !isSearching && (
            <div className="card diary-empty">
              <div className="diary-empty-title">No results for “{trimmed}”</div>
              <div className="text-tertiary">You can create it once and reuse it forever.</div>
            </div>
          )}
        </>
      )}

      <button className="link-button" onClick={() => setShowEditor(true)}>
        + Create custom food
      </button>

      {pending && (
        <LogFoodSheet
          pending={pending}
          dayKey={dayKey}
          initialMeal={initialMeal ?? "snack"}
          onClose={() => closeLogSheet(true)}
        />
      )}
      {showEditor && (
        <CustomFoodEditor prefillName={trimmed} onClose={() => setShowEditor(false)} />
      )}
      {mealToLog && (
        <LogSavedMealSheet
          meal={mealToLog}
          dayKey={dayKey}
          initialMeal={initialMeal ?? "snack"}
          onClose={(didLog) => {
            setMealToLog(null);
            if (didLog) onLogged?.();
          }}
        />
      )}
    </div>
  );
}

function FoodListSection({
  title,
  foods,
  onPick,
}: {
  title: string;
  foods: FoodItem[];
  onPick: (food: FoodItem) => void;
}) {
  return (
    <section>
      <div className="section-header">{title}</div>
      <div className="card list-card">
        {foods.map((food) => (
          <FoodRow
            key={food.id}
            name={food.name}
            brand={food.brand}
            per100g={food.per100g}
            incomplete={false}
            onClick={() => onPick(food)}
          />
        ))}
      </div>
    </section>
  );
}

function ResultsSection({
  title,
  results,
  onPick,
}: {
  title: string;
  results: FoodSearchResult[];
  onPick: (result: FoodSearchResult) => void;
}) {
  return (
    <section>
      <div className="section-header">{title}</div>
      <div className="card list-card">
        {results.map((result) => (
          <FoodRow
            key={result.id}
            name={result.name}
            brand={result.brand}
            sourceLabel={ORIGIN_LABELS[result.origin]}
            per100g={result.per100g}
            incomplete={result.hasIncompleteNutrition}
            onClick={() => onPick(result)}
          />
        ))}
      </div>
    </section>
  );
}

/** One food row: name, source, kcal & protein per 100 g, subdued carbs/fat. */
export function FoodRow({
  name,
  brand,
  sourceLabel,
  per100g,
  incomplete,
  onClick,
}: {
  name: string;
  brand?: string;
  sourceLabel?: string;
  per100g: NutritionValues;
  incomplete: boolean;
  onClick: () => void;
}) {
  return (
    <button className="food-row" onClick={onClick}>
      <span className="food-row-left">
        <span className="food-row-name">
          {name} {incomplete && <span title="Incomplete nutrition data">⚠️</span>}
        </span>
        <span className="food-row-detail">
          {brand && <span>{brand} </span>}
          {sourceLabel && <SourceBadge label={sourceLabel} />}
        </span>
        <span className="food-row-detail">
          C {Format.macroGrams(per100g.carbs)} g · F {Format.macroGrams(per100g.fat)} g per 100 g
        </span>
      </span>
      <span className="food-row-right">
        <span>{Format.kcal(per100g.calories)} kcal</span>
        <span className="food-row-detail">{Format.macroGrams(per100g.protein)} g protein</span>
      </span>
    </button>
  );
}

// Re-exported for SavedMealSheets' component rows.
export { scalePer100g };
