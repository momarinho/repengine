import { test, expect } from '@playwright/test';

test.describe('RepEngine Workout Lifecycle E2E', () => {
	test('Register, log in, create a routine, add a block, save, play, log, and view history', async ({ page }) => {
		page.on('console', msg => {
			console.log(`[BROWSER CONSOLE] [${msg.type()}] ${msg.text()}`);
		});
		page.on('pageerror', err => {
			console.error(`[BROWSER EXCEPTION] ${err.message}`);
		});

		const uniqueSuffix = Date.now() + Math.floor(Math.random() * 1000);
		const uniqueEmail = `e2e_test_${uniqueSuffix}@example.com`;
		const password = 'password123';

		// 1. Go to register page
		await page.goto('/register');
		await expect(page).toHaveTitle(/Register/);

		// 2. Fill register form
		await page.fill('#email', uniqueEmail);
		await page.fill('#password', password);
		await page.click('button[type="submit"]');

		// 3. Should redirect to login
		await page.waitForURL('**/login');
		await expect(page).toHaveTitle(/Login/);

		// 4. Log in
		await page.fill('#email', uniqueEmail);
		await page.fill('#password', password);
		await page.click('button[type="submit"]');

		// 5. Lands on dashboard
		await page.waitForURL('**/dashboard');
		await expect(page.locator('h2')).toContainText('My Routines');
		await page.screenshot({ path: '../docs/screenshots/1-dashboard.png' });

		// 6. Create a new routine
		await page.click('a[href="/dashboard/new"]');

		// 7. Verify we are in the editor
		await page.waitForURL(/\/workflows\/\d+\/edit/);
		await expect(page.locator('input[placeholder="Untitled Routine"]')).toBeVisible();

		// 8. Edit title
		const titleInput = page.locator('input[placeholder="Untitled Routine"]');
		await titleInput.fill('E2E Test Routine');
		await titleInput.blur();

		// 9. Add first block
		await page.click('text=Add first block');
		// Wait for Add Block modal
		await page.waitForSelector('text=All available node types');
		// Select "Linear Progression"
		await page.waitForTimeout(500);
		await page.getByRole('button', { name: /Linear Progression/i }).first().click({ force: true });

		// 10. Verify block is added and configure it
		await expect(page.locator('li').locator('text=Linear Progression').first()).toBeVisible();

		// Click on the block in the canvas to open the sidebar editor
		await page.click('li:has-text("Linear Progression")');

		// Fill details in the sidebar
		await page.fill('#linear-exercise-name', 'Squat');
		await page.fill('#linear-start-load', '100');
		await page.locator('#linear-start-load').blur();

		// 11. Click save manually to make sure it saves
		await page.click('button:has-text("Save Routine")');
		
		// 12. Wait for save to complete
		await page.waitForTimeout(2000);
		await page.screenshot({ path: '../docs/screenshots/2-editor.png' });

		// 13. Open the player
		await page.click('a:has-text("Play")');

		// 14. Should be on the play page
		await page.waitForURL(/\/workflows\/\d+\/play/);

		// Fill actual load to 102.5 and actual RPE to 8
		await page.fill('#actual-load', '102.5');
		await page.fill('#actual-rpe', '8');
		await page.screenshot({ path: '../docs/screenshots/3-player.png' });

		// 15. The player should auto-start or show sections.
		// Since we have no sections, it starts playing block 1 immediately.
		// We click "Log Set" 2 times (for set 1 and set 2), skipping rest timers in between.
		for (let i = 0; i < 2; i++) {
			const skipRestBtn = page.locator('button:has-text("Skip Rest")');
			if (await skipRestBtn.isVisible()) {
				await skipRestBtn.click();
				await page.waitForTimeout(200);
				// Refill load and RPE after skipping rest to ensure it persists
				await page.fill('#actual-load', '102.5');
				await page.fill('#actual-rpe', '8');
			}

			const primaryBtn = page.locator('button:has-text("Log Set")');
			await expect(primaryBtn).toBeVisible();
			await primaryBtn.click();
			await page.waitForTimeout(500); // wait for set log animation/transition
		}

		// 16. For the 3rd set, we skip the rest timer again and click "Complete Exercise".
		const skipRestBtn = page.locator('button:has-text("Skip Rest")');
		if (await skipRestBtn.isVisible()) {
			await skipRestBtn.click();
			await page.waitForTimeout(200);
			await page.fill('#actual-load', '102.5');
			await page.fill('#actual-rpe', '8');
		}

		const completeExerciseBtn = page.locator('button:has-text("Complete Exercise")');
		await expect(completeExerciseBtn).toBeVisible();
		await completeExerciseBtn.click();

		// 17. Since that's the only block, the session should be complete!
		// Let's wait for session complete view
		await expect(page.locator('text=Session complete')).toBeVisible();

		// 18. Click "View history" link
		await page.click('a:has-text("View history")');

		// 19. Should be on the history page and see the analytics chart
		await page.waitForURL(/\/workflows\/\d+\/history/);
		await expect(page.locator('h1')).toContainText('E2E Test Routine history');

		// Assert that the load and routine name are present in the history details
		await expect(page.locator('text=E2E Test Routine').first()).toBeVisible();
		await expect(page.locator('text=102.5').first()).toBeVisible();
		await page.screenshot({ path: '../docs/screenshots/4-history-analytics.png' });
	});

	test('Explore official templates, clone GZCLP Hybrid, and run Jump Rope Interval Timer HUD', async ({ page }) => {
		const uniqueSuffix = Date.now() + Math.floor(Math.random() * 1000);
		const uniqueEmail = `hybrid_test_${uniqueSuffix}@example.com`;
		const password = 'password123';

		// 1. Register & log in
		await page.goto('/register');
		await page.fill('#email', uniqueEmail);
		await page.fill('#password', password);
		await page.click('button[type="submit"]');

		await page.waitForURL('**/login');
		await page.fill('#email', uniqueEmail);
		await page.fill('#password', password);
		await page.click('button[type="submit"]');
		await page.waitForURL('**/dashboard');

		// 2. Go to templates page
		await page.goto('/templates');
		const hybridCard = page.locator('article', { hasText: 'GZCLP Calisthenics & Barbell Hybrid' });
		await expect(hybridCard).toBeVisible();

		// 3. Click Preview link
		await hybridCard.locator('a:has-text("Preview")').click();
		await page.waitForURL(/\/templates\/\d+/);

		// 4. Clone template
		await page.click('button:has-text("Use Template")');
		await page.waitForURL(/\/workflows\/\d+\/edit/, { timeout: 15000 });

		// 5. Open player
		const playLink = page.locator('a[href*="/play"]');
		await playLink.click();
		await page.waitForURL(/\/workflows\/\d+\/play/);

		// 6. Section chooser: select "Jump Rope & Abs A"
		const jumpRopeSectionBtn = page.locator('button:has-text("Jump Rope & Abs A")');
		if (await jumpRopeSectionBtn.isVisible()) {
			await jumpRopeSectionBtn.click();
		}

		// Click "Start Section" to advance into the jump rope block
		const startSectionBtn = page.locator('button:has-text("Start Section")');
		await expect(startSectionBtn).toBeVisible({ timeout: 5000 });
		await startSectionBtn.click();

		// 7. Check Interval Timer HUD
		await expect(page.locator('text=Interval Circuit')).toBeVisible();
		await expect(page.locator('text=Round 1').first()).toBeVisible();
		await expect(page.locator('text=50% Moderate Pace').first()).toBeVisible();

		// Scroll the timer into view for a beautiful screenshot
		const timerCard = page.locator('text=50% Moderate Pace').first();
		await timerCard.scrollIntoViewIfNeeded();

		// 8. Capture screenshot of the Interval Timer HUD for documentation
		await page.screenshot({ path: '../docs/screenshots/5-interval-timer.png' });

		// 9. Start intervals
		const startBtn = page.locator('button:has-text("Start Intervals")').first();
		await startBtn.click();
		await page.waitForTimeout(300);

		// 10. Verify active running state
		await expect(page.locator('button:has-text("Pause Timer"), button:has-text("Pause Intervals")').first()).toBeVisible();

		// 11. Skip phase -> Sprint MAX
		const skipPhaseBtn = page.locator('button:has-text("Skip Phase")').first();
		await skipPhaseBtn.click();
		await page.waitForTimeout(200);
		await expect(page.locator('text=Sprint MAX').first()).toBeVisible();

		// 12. Skip phase -> Complete Rest
		await skipPhaseBtn.click();
		await page.waitForTimeout(200);
		await expect(page.locator('text=Complete Rest').first()).toBeVisible();

		// 13. Skip phase -> Round 1 completes, advances to Round 2
		await skipPhaseBtn.click();
		await page.waitForTimeout(400);
		await expect(page.locator('text=Round 2').first()).toBeVisible();
	});
});
