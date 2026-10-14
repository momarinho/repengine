import { test, expect } from '@playwright/test';
import { execSync } from 'node:child_process';
import path from 'node:path';
import fs from 'node:fs';

test.use({
	viewport: { width: 1280, height: 720 },
	deviceScaleFactor: 1.5,
	video: {
		mode: 'on',
		size: { width: 1280, height: 720 }
	}
});

test.describe('RepEngine Desktop Web Studio & Player Demo Video Recording', () => {
	test('Record high-impact desktop web studio and workout player demo', async ({ page, context }) => {
		test.setTimeout(120000);

		// Inject visible mouse pointer and click ripple for high-production desktop video
		await page.addInitScript(() => {
			// Virtual smooth cursor dot
			const cursor = document.createElement('div');
			cursor.id = '__demo_cursor';
			cursor.style.position = 'fixed';
			cursor.style.width = '18px';
			cursor.style.height = '18px';
			cursor.style.borderRadius = '50%';
			cursor.style.backgroundColor = 'rgba(74, 222, 128, 0.9)';
			cursor.style.border = '2px solid rgba(255, 255, 255, 0.95)';
			cursor.style.boxShadow = '0 0 14px rgba(74, 222, 128, 0.8), 0 2px 6px rgba(0,0,0,0.4)';
			cursor.style.pointerEvents = 'none';
			cursor.style.zIndex = '9999999';
			cursor.style.transform = 'translate(-50%, -50%)';
			cursor.style.transition = 'transform 0.12s ease-out, background-color 0.2s ease';
			document.body.appendChild(cursor);

			window.addEventListener('mousemove', (e) => {
				cursor.style.left = `${e.clientX}px`;
				cursor.style.top = `${e.clientY}px`;
			});

			window.addEventListener('mousedown', (e) => {
				cursor.style.transform = 'translate(-50%, -50%) scale(0.7)';
				cursor.style.backgroundColor = 'rgba(34, 197, 94, 1)';

				const ripple = document.createElement('div');
				ripple.style.position = 'fixed';
				ripple.style.left = `${e.clientX - 25}px`;
				ripple.style.top = `${e.clientY - 25}px`;
				ripple.style.width = '50px';
				ripple.style.height = '50px';
				ripple.style.borderRadius = '50%';
				ripple.style.border = '2px solid rgba(74, 222, 128, 0.85)';
				ripple.style.boxShadow = '0 0 16px rgba(74, 222, 128, 0.6)';
				ripple.style.pointerEvents = 'none';
				ripple.style.zIndex = '9999998';
				ripple.style.transform = 'scale(0.5)';
				ripple.style.transition = 'transform 0.4s cubic-bezier(0.16, 1, 0.3, 1), opacity 0.4s ease-out';
				document.body.appendChild(ripple);

				requestAnimationFrame(() => {
					ripple.style.transform = 'scale(1.5)';
					ripple.style.opacity = '0';
				});
				setTimeout(() => ripple.remove(), 420);
			});

			window.addEventListener('mouseup', () => {
				cursor.style.transform = 'translate(-50%, -50%) scale(1)';
				cursor.style.backgroundColor = 'rgba(74, 222, 128, 0.9)';
			});
		});

		const uniqueSuffix = Date.now();
		const demoEmail = `mateus.marinho+webdemo${uniqueSuffix}@repengine.app`;
		const password = 'demoPassword123!';

		// 1. Register & Login
		console.log('[STEP 1] Navigating to register');
		await page.goto('/register');
		await page.waitForTimeout(600);
		await page.fill('#email', demoEmail);
		await page.fill('#password', password);
		await page.waitForTimeout(400);
		await page.click('button[type="submit"]');

		console.log('[STEP 2] Logging in');
		await page.waitForURL('**/login');
		await page.waitForTimeout(400);
		await page.fill('#email', demoEmail);
		await page.fill('#password', password);
		await page.waitForTimeout(400);
		await page.click('button[type="submit"]');

		// 2. Lands on Dashboard
		console.log('[STEP 3] Dashboard overview');
		await page.waitForURL('**/dashboard');
		await page.waitForTimeout(1400);

		// 3. Navigate to Templates Library
		console.log('[STEP 4] Templates Library');
		await page.goto('/templates');
		await page.waitForTimeout(1200);

		// Find the official routine card
		const routineCard = page.locator('article', {
			hasText: 'Beginner 3-Day Physique & Functional Core Routine'
		});
		await routineCard.scrollIntoViewIfNeeded();
		await page.waitForTimeout(1000);

		// Click "Preview"
		await routineCard.getByRole('link', { name: /preview/i }).first().click();
		await page.waitForURL(/\/templates\/\d+/);
		await page.waitForTimeout(1500);

		// 4. Click "Use Template" to clone into personal studio
		console.log('[STEP 5] Cloning Template into Studio Editor');
		const useTemplateBtn = page.getByRole('button', { name: /use template/i }).first();
		await useTemplateBtn.scrollIntoViewIfNeeded();
		await page.waitForTimeout(600);
		await useTemplateBtn.click();

		// Wait for clone and redirect to Studio Editor
		await page.waitForURL(/\/workflows\/\d+\/edit/, { timeout: 25000 });
		await page.waitForTimeout(1800);

		// Showcase the Routine Studio on Desktop:
		// Scroll gently to see Day 1 and exercise blocks
		console.log('[STEP 6] Exploring Studio Routine Architecture');
		await page.mouse.wheel(0, 300);
		await page.waitForTimeout(1200);
		await page.mouse.wheel(0, -300);
		await page.waitForTimeout(1000);

		// 5. Click "Play" in Header to start execution
		console.log('[STEP 7] Launching Workout Player');
		const playLink = page.locator('a:has-text("Play")').first();
		await playLink.click();
		await page.waitForURL(/\/workflows\/\d+\/play/);
		await page.waitForTimeout(1500);

		// 6. Section selection: Day 1
		console.log('[STEP 8] Selecting Day 1');
		const continueNextBtn = page.locator('button:has-text("Continue to Next")');
		if (await continueNextBtn.isVisible()) {
			await continueNextBtn.click();
		} else {
			const day1Btn = page.locator('button:has-text("Day 1 - Quads")').first();
			if (await day1Btn.isVisible()) {
				await day1Btn.click();
			}
		}
		await page.waitForTimeout(1000);

		// Confirm & Start Workout in Load Preview sheet
		console.log('[STEP 9] Confirming Workout');
		const confirmStartBtn = page.locator('button:has-text("Confirm & Start Workout")');
		if (await confirmStartBtn.isVisible()) {
			await confirmStartBtn.click();
		}
		await page.waitForTimeout(1200);

		// Advance past Section intro block by clicking "Start Section"
		const startSectionBtn = page.locator('button:has-text("Start Section")').first();
		if (await startSectionBtn.isVisible()) {
			console.log('[STEP 9.1] Clicking Start Section');
			await startSectionBtn.click();
		}
		await page.waitForTimeout(1400);

		// 7. Desktop Workout Player: Smith Machine Squat
		console.log('[STEP 10] Exercising: Smith Machine Squat');
		await expect(page.getByRole('heading', { name: /Smith Machine Squat/i }).first()).toBeVisible();
		await page.waitForTimeout(1200);

		// Interact with Steppers: Increase reps
		const addRepsBtn = page.locator('button[aria-label="Increase reps"]');
		if (await addRepsBtn.isVisible()) {
			await addRepsBtn.click();
			await page.waitForTimeout(500);
			await addRepsBtn.click();
			await page.waitForTimeout(700);
		}

		// Interact with quick load: tap +2.5 pill
		const add25LoadBtn = page.locator('button:has-text("+2.5")').first();
		if (await add25LoadBtn.isVisible()) {
			await add25LoadBtn.click();
			await page.waitForTimeout(800);
		}

		// 8. Log Set 1
		console.log('[STEP 11] Logging Set 1');
		const logSetBtn = page.locator('button:has-text("Log Set")').last();
		await logSetBtn.click();
		await page.waitForTimeout(1000);

		// 9. Rest timer emerges!
		console.log('[STEP 12] Rest timer Active');
		await expect(page.locator('text=Rest between sets').or(page.locator('button:has-text("Skip Rest")')).first()).toBeVisible();
		await page.waitForTimeout(2500); // let timer tick down visibly

		// Click "Skip Rest" in control bar
		const skipRestBtn = page.locator('button:has-text("Skip Rest")').first();
		await skipRestBtn.click();
		await page.waitForTimeout(1200);

		// 10. Set 2: Auto-carry-forward
		console.log('[STEP 13] Set 2 Auto-Carry-Forward');
		await expect(page.getByRole('heading', { name: /Smith Machine Squat/i }).first()).toBeVisible();
		await page.waitForTimeout(1200);

		// Log Set 2
		const logSet2Btn = page.locator('button:has-text("Log Set")').last();
		await logSet2Btn.click();
		await page.waitForTimeout(1500);

		// Skip rest to advance
		const skipBtn2 = page.locator('button:has-text("Skip Rest")').first();
		if (await skipBtn2.isVisible()) {
			await skipBtn2.click();
			await page.waitForTimeout(1200);
		}

		// 11. Set 3 / Complete Exercise
		console.log('[STEP 14] Completing Exercise');
		const completeExerciseBtn = page.locator('button:has-text("Complete Exercise")').or(page.locator('button:has-text("Log Set")')).last();
		if (await completeExerciseBtn.isVisible()) {
			await completeExerciseBtn.click();
		}
		await page.waitForTimeout(2500);

		// Close context to finalize Playwright video file
		const video = page.video();
		await context.close();

		const videoPath = await video?.path();
		console.log(`[PLAYWRIGHT DESKTOP VIDEO RECORDED]: ${videoPath}`);

		if (videoPath && fs.existsSync(videoPath)) {
			const outputMp4 = path.resolve('../docs/videos/repengine-web-desktop-demo.mp4');
			console.log(`[CONVERTING WITH FFMPEG] -> ${outputMp4}`);

			// Convert webm to crystal clear h264 mp4 1080p-ready with faststart
			const ffmpegCmd = `ffmpeg -y -i "${videoPath}" -c:v libx264 -preset slow -crf 19 -pix_fmt yuv420p -profile:v high -level 4.1 -movflags +faststart "${outputMp4}"`;
			execSync(ffmpegCmd, { stdio: 'inherit' });

			console.log(`[SUCCESS] Desktop MP4 Video generated at: ${outputMp4}`);

			// Generate thumbnails
			try {
				const thumbStudio = path.resolve('../docs/videos/demo-desktop-thumbnail-studio.png');
				const thumbPlayer = path.resolve('../docs/videos/demo-desktop-thumbnail-player.png');
				execSync(`ffmpeg -y -ss 00:00:14 -i "${outputMp4}" -vframes 1 -q:v 2 "${thumbStudio}"`, { stdio: 'ignore' });
				execSync(`ffmpeg -y -ss 00:00:23 -i "${outputMp4}" -vframes 1 -q:v 2 "${thumbPlayer}"`, { stdio: 'ignore' });
				console.log(`[SUCCESS] Desktop Thumbnails generated at: ${thumbStudio} and ${thumbPlayer}`);
			} catch (err) {
				console.warn('Failed to extract thumbnails:', err);
			}
		}
	});
});
