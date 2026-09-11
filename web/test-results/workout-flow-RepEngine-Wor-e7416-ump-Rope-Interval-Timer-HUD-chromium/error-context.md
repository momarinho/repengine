# Instructions

- Following Playwright test failed.
- Explain why, be concise, respect Playwright best practices.
- Provide a snippet of code with the fix, if possible.

# Test info

- Name: workout-flow.spec.ts >> RepEngine Workout Lifecycle E2E >> Explore official templates, clone GZCLP Hybrid, and run Jump Rope Interval Timer HUD
- Location: tests/workout-flow.spec.ts:137:2

# Error details

```
Error: expect(locator).toBeVisible() failed

Locator: locator('text=Interval Circuit')
Expected: visible
Timeout: 5000ms
Error: element(s) not found

Call log:
  - Expect "toBeVisible" with timeout 5000ms
  - waiting for locator('text=Interval Circuit')

```

```yaml
- banner:
  - paragraph: GZCLP Calisthenics & Barbell Hybrid
  - text: schedule 00:04
  - link "edit":
    - /url: /workflows/7/edit
- main:
  - paragraph: Active block
  - text: cardio · Jump Rope & Abs A
  - heading "Jump Rope & Abs A" [level=1]
  - paragraph: High-intensity 30/15/15 intervals followed by vertical core compression and anti-extension holds.
  - paragraph: High-intensity 30/15/15 intervals followed by vertical core compression and anti-extension holds.
  - text: "#7 • active"
  - paragraph: Section
  - heading "Jump Rope & Abs A" [level=2]
  - paragraph: High-intensity 30/15/15 intervals followed by vertical core compression and anti-extension holds.
  - text: Section
  - paragraph: Section objective
  - paragraph: High-intensity 30/15/15 intervals followed by vertical core compression and anti-extension holds.
  - paragraph: Use section blocks as checkpoints between exercise groups, waves, and finishers.
  - text: Block notes
  - textbox "Block notes":
    - /placeholder: Execution notes for this block...
  - complementary:
    - heading "Up next" [level=3]
    - button "Jump Rope 30/15/15 Intervals (8 Rounds) Repeat• 30s @ 50% Pace -> 15s Sprint MAX -> 15s Complete Rest":
      - paragraph: Jump Rope 30/15/15 Intervals (8 Rounds)
      - paragraph: Repeat• 30s @ 50% Pace -> 15s Sprint MAX -> 15s Complete Rest
    - button "Rest Rest":
      - paragraph: Rest
      - paragraph: Rest
    - button "Hanging Knee / Leg Raise Exercise• 10-12":
      - paragraph: Hanging Knee / Leg Raise
      - paragraph: Exercise• 10-12
    - heading "Completed" [level=3]
    - text: No blocks completed yet.
    - heading "Session log" [level=3]
    - text: Elapsed 00:04 Blocks complete 0 Sets logged 0 Rounds logged 0 Notes captured 0
    - paragraph: Session sync
    - button "Reset"
    - paragraph: "Persisted session #7 • active is receiving new logs."
    - link "Open history":
      - /url: /workflows/7/history
    - button "Abandon session"
    - heading "Recent sessions" [level=4]
    - paragraph: Jump Rope & Abs A
    - text: active
    - paragraph: Sep 10, 10:54 PM
    - text: 0 logs In progress
- contentinfo:
  - button "skip_previous"
  - button "Start Section"
  - button "skip_next"
- text: GZCLP Calisthenics & Barbell Hybrid - Workout Player - RepEngine
```

# Test source

```ts
  85  | 		await page.fill('#actual-rpe', '8');
  86  | 		await page.screenshot({ path: '../docs/screenshots/3-player.png' });
  87  | 
  88  | 		// 15. The player should auto-start or show sections.
  89  | 		// Since we have no sections, it starts playing block 1 immediately.
  90  | 		// We click "Log Set" 2 times (for set 1 and set 2), skipping rest timers in between.
  91  | 		for (let i = 0; i < 2; i++) {
  92  | 			const skipRestBtn = page.locator('button:has-text("Skip Rest")');
  93  | 			if (await skipRestBtn.isVisible()) {
  94  | 				await skipRestBtn.click();
  95  | 				await page.waitForTimeout(200);
  96  | 				// Refill load and RPE after skipping rest to ensure it persists
  97  | 				await page.fill('#actual-load', '102.5');
  98  | 				await page.fill('#actual-rpe', '8');
  99  | 			}
  100 | 
  101 | 			const primaryBtn = page.locator('button:has-text("Log Set")');
  102 | 			await expect(primaryBtn).toBeVisible();
  103 | 			await primaryBtn.click();
  104 | 			await page.waitForTimeout(500); // wait for set log animation/transition
  105 | 		}
  106 | 
  107 | 		// 16. For the 3rd set, we skip the rest timer again and click "Complete Exercise".
  108 | 		const skipRestBtn = page.locator('button:has-text("Skip Rest")');
  109 | 		if (await skipRestBtn.isVisible()) {
  110 | 			await skipRestBtn.click();
  111 | 			await page.waitForTimeout(200);
  112 | 			await page.fill('#actual-load', '102.5');
  113 | 			await page.fill('#actual-rpe', '8');
  114 | 		}
  115 | 
  116 | 		const completeExerciseBtn = page.locator('button:has-text("Complete Exercise")');
  117 | 		await expect(completeExerciseBtn).toBeVisible();
  118 | 		await completeExerciseBtn.click();
  119 | 
  120 | 		// 17. Since that's the only block, the session should be complete!
  121 | 		// Let's wait for session complete view
  122 | 		await expect(page.locator('text=Session complete')).toBeVisible();
  123 | 
  124 | 		// 18. Click "View history" link
  125 | 		await page.click('a:has-text("View history")');
  126 | 
  127 | 		// 19. Should be on the history page and see the analytics chart
  128 | 		await page.waitForURL(/\/workflows\/\d+\/history/);
  129 | 		await expect(page.locator('h1')).toContainText('E2E Test Routine history');
  130 | 
  131 | 		// Assert that the load and routine name are present in the history details
  132 | 		await expect(page.locator('text=E2E Test Routine').first()).toBeVisible();
  133 | 		await expect(page.locator('text=102.5').first()).toBeVisible();
  134 | 		await page.screenshot({ path: '../docs/screenshots/4-history-analytics.png' });
  135 | 	});
  136 | 
  137 | 	test('Explore official templates, clone GZCLP Hybrid, and run Jump Rope Interval Timer HUD', async ({ page }) => {
  138 | 		const uniqueSuffix = Date.now() + Math.floor(Math.random() * 1000);
  139 | 		const uniqueEmail = `hybrid_test_${uniqueSuffix}@example.com`;
  140 | 		const password = 'password123';
  141 | 
  142 | 		// 1. Register & log in
  143 | 		await page.goto('/register');
  144 | 		await page.fill('#email', uniqueEmail);
  145 | 		await page.fill('#password', password);
  146 | 		await page.click('button[type="submit"]');
  147 | 
  148 | 		await page.waitForURL('**/login');
  149 | 		await page.fill('#email', uniqueEmail);
  150 | 		await page.fill('#password', password);
  151 | 		await page.click('button[type="submit"]');
  152 | 		await page.waitForURL('**/dashboard');
  153 | 
  154 | 		// 2. Go to templates page
  155 | 		await page.goto('/templates');
  156 | 		const hybridCard = page.locator('article', { hasText: 'GZCLP Calisthenics & Barbell Hybrid' });
  157 | 		await expect(hybridCard).toBeVisible();
  158 | 
  159 | 		// 3. Click Preview link
  160 | 		await hybridCard.locator('a:has-text("Preview")').click();
  161 | 		await page.waitForURL(/\/templates\/\d+/);
  162 | 
  163 | 		// 4. Clone template
  164 | 		await page.click('button:has-text("Use Template")');
  165 | 		await page.waitForURL(/\/workflows\/\d+\/edit/, { timeout: 15000 });
  166 | 
  167 | 		// 5. Open player
  168 | 		const playLink = page.locator('a[href*="/play"]');
  169 | 		await playLink.click();
  170 | 		await page.waitForURL(/\/workflows\/\d+\/play/);
  171 | 
  172 | 		// 6. Section chooser: select "Jump Rope & Abs A"
  173 | 		const jumpRopeSectionBtn = page.locator('button:has-text("Jump Rope & Abs A")');
  174 | 		if (await jumpRopeSectionBtn.isVisible()) {
  175 | 			await jumpRopeSectionBtn.click();
  176 | 		}
  177 | 
  178 | 		// Click "Start Section" to advance into the jump rope block
  179 | 		const startSectionBtn = page.locator('button:has-text("Start Section")');
  180 | 		if (await startSectionBtn.isVisible()) {
  181 | 			await startSectionBtn.click();
  182 | 		}
  183 | 
  184 | 		// 7. Check Interval Timer HUD
> 185 | 		await expect(page.locator('text=Interval Circuit')).toBeVisible();
      |                                                       ^ Error: expect(locator).toBeVisible() failed
  186 | 		await expect(page.locator('text=Round 1').first()).toBeVisible();
  187 | 		await expect(page.locator('text=50% Moderate Pace').first()).toBeVisible();
  188 | 
  189 | 		// 8. Capture screenshot of the Interval Timer HUD for documentation
  190 | 		await page.screenshot({ path: '../docs/screenshots/5-interval-timer.png' });
  191 | 
  192 | 		// 9. Start intervals
  193 | 		const startBtn = page.locator('button:has-text("Start Intervals")').first();
  194 | 		await startBtn.click();
  195 | 		await page.waitForTimeout(300);
  196 | 
  197 | 		// 10. Verify active running state
  198 | 		await expect(page.locator('button:has-text("Pause Timer"), button:has-text("Pause Intervals")').first()).toBeVisible();
  199 | 
  200 | 		// 11. Skip phase -> Sprint MAX
  201 | 		const skipPhaseBtn = page.locator('button:has-text("Skip Phase")').first();
  202 | 		await skipPhaseBtn.click();
  203 | 		await page.waitForTimeout(200);
  204 | 		await expect(page.locator('text=Sprint MAX').first()).toBeVisible();
  205 | 
  206 | 		// 12. Skip phase -> Complete Rest
  207 | 		await skipPhaseBtn.click();
  208 | 		await page.waitForTimeout(200);
  209 | 		await expect(page.locator('text=Complete Rest').first()).toBeVisible();
  210 | 
  211 | 		// 13. Skip phase -> Round 1 completes, advances to Round 2
  212 | 		await skipPhaseBtn.click();
  213 | 		await page.waitForTimeout(400);
  214 | 		await expect(page.locator('text=Round 2').first()).toBeVisible();
  215 | 	});
  216 | });
  217 | 
```