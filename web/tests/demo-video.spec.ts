import { test, expect } from '@playwright/test';
import { execSync } from 'node:child_process';
import path from 'node:path';
import fs from 'node:fs';

test.use({
	viewport: { width: 390, height: 844 },
	deviceScaleFactor: 2,
	isMobile: true,
	hasTouch: true,
	userAgent:
		'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1',
	video: {
		mode: 'on',
		size: { width: 390, height: 844 }
	}
});

test.describe('RepEngine Mobile Demo Video Recording', () => {
	test('Record high-impact mobile workout player demo', async ({ page, context }) => {
		test.setTimeout(90000);

		// Inject touch ripple effect and gym mock APIs (vibrate, wakeLock)
		await page.addInitScript(() => {
			(window as any).__vibrateCalls = [];
			(window as any).__wakeLockRequested = false;

			(navigator as any).vibrate = (pattern: any) => {
				(window as any).__vibrateCalls.push(pattern);
				return true;
			};

			if (!('wakeLock' in navigator)) {
				(navigator as any).wakeLock = {
					request: async (type: string) => {
						(window as any).__wakeLockRequested = true;
						return {
							type,
							released: false,
							release: async () => {}
						};
					}
				};
			}

			// Add visual touch tap ripple indicator for demo video recording
			window.addEventListener(
				'pointerdown',
				(e) => {
					const dot = document.createElement('div');
					dot.style.position = 'fixed';
					dot.style.left = `${e.clientX - 20}px`;
					dot.style.top = `${e.clientY - 20}px`;
					dot.style.width = '40px';
					dot.style.height = '40px';
					dot.style.borderRadius = '50%';
					dot.style.backgroundColor = 'rgba(74, 222, 128, 0.45)';
					dot.style.border = '2.5px solid rgba(74, 222, 128, 0.9)';
					dot.style.boxShadow = '0 0 16px rgba(74, 222, 128, 0.7)';
					dot.style.pointerEvents = 'none';
					dot.style.zIndex = '999999';
					dot.style.transform = 'scale(0.6)';
					dot.style.transition = 'transform 0.35s ease-out, opacity 0.35s ease-out';
					document.body.appendChild(dot);
					requestAnimationFrame(() => {
						dot.style.transform = 'scale(1.4)';
						dot.style.opacity = '0';
					});
					setTimeout(() => dot.remove(), 360);
				},
				true
			);
		});

		const uniqueSuffix = Date.now();
		const demoEmail = `mateus.marinho+demo${uniqueSuffix}@repengine.app`;
		const password = 'demoPassword123!';

		// 1. Register & Login
		console.log('[STEP 1] Navigating to register');
		await page.goto('/register');
		await page.waitForTimeout(600);
		await page.fill('#email', demoEmail);
		await page.fill('#password', password);
		await page.waitForTimeout(300);
		await page.click('button[type="submit"]');

		console.log('[STEP 2] Logging in');
		await page.waitForURL('**/login');
		await page.waitForTimeout(400);
		await page.fill('#email', demoEmail);
		await page.fill('#password', password);
		await page.waitForTimeout(300);
		await page.click('button[type="submit"]');

		// 2. Lands on Dashboard
		console.log('[STEP 3] Dashboard');
		await page.waitForURL('**/dashboard');
		await page.waitForTimeout(1000);

		// 3. Navigate to Templates Library
		console.log('[STEP 4] Templates Library');
		await page.goto('/templates');
		await page.waitForTimeout(1000);

		// Find the official "Beginner 3-Day Physique & Functional Core Routine" card
		const routineCard = page.locator('article', {
			hasText: 'Beginner 3-Day Physique & Functional Core Routine'
		});
		await routineCard.scrollIntoViewIfNeeded();
		await page.waitForTimeout(800);

		// Click "Preview Routine"
		await routineCard.locator('a:has-text("Preview Routine")').click();
		await page.waitForURL(/\/templates\/\d+/);
		await page.waitForTimeout(1200);

		// 4. Click visible mobile "Use Template" button (in the fixed bottom bar)
		console.log('[STEP 5] Cloning Template');
		const useTemplateBtn = page.locator('button:has-text("Use Template")').last();
		await useTemplateBtn.scrollIntoViewIfNeeded();
		await page.waitForTimeout(600);
		await useTemplateBtn.click();

		// Wait for clone job to complete and redirect to editor
		await page.waitForURL(/\/workflows\/\d+\/edit/, { timeout: 25000 });
		await page.waitForTimeout(1200);

		// 5. Click "Play" in Header
		console.log('[STEP 6] Opening Player');
		const playLink = page.locator('a:has-text("Play")').first();
		await playLink.click();
		await page.waitForURL(/\/workflows\/\d+\/play/);
		await page.waitForTimeout(1200);

		// 6. Section selection: Day 1 - Quads, Glutes, Push & Upper Ab Flexion
		console.log('[STEP 7] Selecting Section');
		const continueNextBtn = page.locator('button:has-text("Continue to Next")');
		if (await continueNextBtn.isVisible()) {
			await continueNextBtn.click();
		} else {
			const day1Btn = page.locator('button:has-text("Day 1 - Quads")').first();
			if (await day1Btn.isVisible()) {
				await day1Btn.click();
			}
		}
		await page.waitForTimeout(800);

		// Confirm & Start Workout in Load Preview sheet
		console.log('[STEP 8] Confirming Workout');
		const confirmStartBtn = page.locator('button:has-text("Confirm & Start Workout")');
		if (await confirmStartBtn.isVisible()) {
			await confirmStartBtn.click();
		}
		await page.waitForTimeout(1000);

		// Advance past Section intro block by clicking "Start Section"
		const startSectionBtn = page.locator('button:has-text("Start Section")').first();
		if (await startSectionBtn.isVisible()) {
			console.log('[STEP 8.1] Clicking Start Section');
			await startSectionBtn.click();
		}
		await page.waitForTimeout(1200);

		// 7. Workout Player: Smith Machine Squat (Set 1 of 3)
		console.log('[STEP 9] Exercising: Smith Machine Squat');
		await expect(page.getByRole('heading', { name: /Smith Machine Squat/i }).first()).toBeVisible();
		await page.waitForTimeout(1200);

		// Use tactile steppers on Reps: increment from target to 10
		const addRepsBtn = page.locator('button[aria-label="Increase reps"]');
		if (await addRepsBtn.isVisible()) {
			await addRepsBtn.click();
			await page.waitForTimeout(500);
			await addRepsBtn.click();
			await page.waitForTimeout(700);
		}

		// Use tactile steppers on Load: tap +2.5 pill
		const add25LoadBtn = page.locator('button:has-text("+2.5")').first();
		if (await add25LoadBtn.isVisible()) {
			await add25LoadBtn.click();
			await page.waitForTimeout(900);
		}

		// 8. Log Set 1
		console.log('[STEP 10] Logging Set 1');
		const logSetBtn = page.locator('button:has-text("Log Set")').last();
		await logSetBtn.click();
		await page.waitForTimeout(900);

		// 9. Rest HUD emerges!
		console.log('[STEP 11] Rest HUD');
		await expect(page.locator('text=Rest in Progress').first()).toBeVisible();
		await page.waitForTimeout(1800); // let the timer tick down

		// Tap +30s to adjust rest time
		const plus30Btn = page.locator('button:has-text("+30s")').first();
		if (await plus30Btn.isVisible()) {
			await plus30Btn.click();
			await page.waitForTimeout(1000);
		}

		// Tap "Start Now" in Rest HUD
		const startNowBtn = page.locator('button:has-text("Start Now")').first();
		if (await startNowBtn.isVisible()) {
			await startNowBtn.click();
		} else {
			await page.locator('button:has-text("Skip Rest")').first().click();
		}
		await page.waitForTimeout(1200);

		// 10. Set 2: Notice auto-carry-forward and Set 1 completed checkmark in Matrix
		console.log('[STEP 12] Set 2 Auto-Carry-Forward');
		await expect(page.getByRole('heading', { name: /Smith Machine Squat/i })).toBeVisible();
		await page.waitForTimeout(1200);

		// Log Set 2 (1-tap set logging thanks to smart prefilling)
		const logSet2Btn = page.locator('button:has-text("Log Set")').last();
		await logSet2Btn.click();
		await page.waitForTimeout(1200);

		// Skip rest for set 2 to proceed to final set
		const startNowBtn2 = page.locator('button:has-text("Start Now")').first();
		if (await startNowBtn2.isVisible()) {
			await startNowBtn2.click();
		} else {
			const skipBtn = page.locator('button:has-text("Skip Rest")').first();
			if (await skipBtn.isVisible()) {
				await skipBtn.click();
			}
		}
		await page.waitForTimeout(1200);

		// 11. Set 3: Complete Exercise
		console.log('[STEP 13] Completing Exercise');
		const completeExerciseBtn = page.locator('button:has-text("Complete Exercise")').last();
		if (await completeExerciseBtn.isVisible()) {
			await completeExerciseBtn.click();
		}
		await page.waitForTimeout(2500);

		// Close context so Playwright finalizes the video recording file
		const video = page.video();
		await context.close();

		const videoPath = await video?.path();
		console.log(`[PLAYWRIGHT VIDEO RECORDED]: ${videoPath}`);

		if (videoPath && fs.existsSync(videoPath)) {
			const outputMp4 = path.resolve('../docs/videos/repengine-mobile-demo.mp4');
			console.log(`[CONVERTING WITH FFMPEG] -> ${outputMp4}`);

			// Convert webm to h264 mp4 optimized for web and mobile LinkedIn upload
			const ffmpegCmd = `ffmpeg -y -i "${videoPath}" -c:v libx264 -preset slow -crf 20 -pix_fmt yuv420p -profile:v high -level 4.0 -movflags +faststart "${outputMp4}"`;
			execSync(ffmpegCmd, { stdio: 'inherit' });

			console.log(`[SUCCESS] MP4 Video generated at: ${outputMp4}`);
		}
	});
});
