# Art bot

Every day a GitHub Action (`.github/workflows/art-bot.yml`) spends the day's PixelLab
generations (5) on the next prompts in `queue.json` and commits the pictures to the
**`art-drafts`** branch. Nothing in the game changes: you review the drafts and copy
the keepers into `assets/` yourself.

## One-time setup
1. **Add the key to GitHub.** On github.com open the repo, then **Settings → Secrets and
   variables → Actions → New repository secret**. Name: `PIXELLAB_SECRET`. Value: your
   key from pixellab.ai/account. Never put the key in a file in the repo: the repo is
   public.
2. **Test it.** Open the **Actions** tab → **Art bot** → **Run workflow**. Tick "Only
   list what would be made" for a free test, or leave it unticked to spend today's
   generations now. The run's log shows each prompt and your PixelLab balance.
3. **Get a local folder.** In GitHub Desktop: **File → Clone repository**, pick
   Final-Wars, and choose a new folder (for example `Documents\Final-Wars-Art`). Then
   switch that copy to the `art-drafts` branch (Current branch → art-drafts). Each
   time you click **Fetch / Pull origin** there, the new drafts appear in that folder.
   Keep it separate from the folder where you work on the game.

The `art-drafts` branch only exists after the first real run.

## What you'll find on `art-drafts`
- `README.md`: every draft with its picture and prompt, newest first. Easiest to read
  on github.com (switch the branch selector to `art-drafts`).
- `art/<ID>/<ID>-<n>_<date>.png`: the pictures, by art tracker ID.
- `progress.json`: which prompts are done, failures, and a log of each run.

## Changing what it makes
- **Order or wording:** edit `queue.json` here on the main branch. Items run top to
  bottom; each prompt is `subject` + its kind's `suffix` (the shared style text) at the
  kind's `size` (or the prompt's own `size`).
- **Make a prompt again:** on the `art-drafts` branch, delete its key (for example
  `"NP-02-1"`) from `"done"` in `progress.json`. A prompt that failed 3 times is skipped
  until you delete it from `"failures"`.
- **Time of day:** the `cron` line in the workflow (UTC).

## Limits
- One still picture per prompt (PixelLab's PixFlux model). Animations, 8 directions
  and "the same character" consistency are left for hand work in PixelLab; the review
  page lists the animation each draft still needs.
- When PixelLab says the day's generations are used up, the bot stops and tries the
  rest tomorrow.

## Run it on your own computer
`python tools/art_bot/art_bot.py --drafts <folder> --dry-run` lists the next prompts.
Without `--dry-run`, set `PIXELLAB_SECRET` first.
