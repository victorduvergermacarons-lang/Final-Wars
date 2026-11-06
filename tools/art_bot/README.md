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

## Approving a base (new weapons, outfits, 8 directions, animations)
PixelLab doesn't remember earlier pictures, so "the same young adventurer" in a new
prompt would draw someone new. Instead the bot builds on a picture you approve:

1. On the `art-drafts` branch, pick the draft you like and put a copy in the
   `approved/` folder, named by its key: `approved/PL-01-1.png`. (In your local
   art-drafts folder: copy the file, rename it, then Commit and Push in GitHub
   Desktop. Or upload it on github.com with **Add file → Upload files** into
   `approved/`.)
2. From the next run on, the prompts that build on it are made from that picture:
   - PL-01-2 (bending stance), PL-02 (sword, bow) and PL-03 (armor) from `PL-01-1`
   - BO-06-1 (Caedan with Stillheart) from `NP-02-1` (Caedan)
3. After every still in the queue is done (the tracker's rule: animations come after
   every reference), each approved character gets its **8 directions** and the
   **animations** listed for it, made from the approved picture. Animations come as
   frames, a one-row sheet and a GIF preview.

The review page lists what is waiting for which approval. Replace an approved file to
change the base; delete a draft's key from `progress.json` to have it made again.

## Changing what it makes
- **Order or wording:** edit `queue.json` here on the main branch. Items run top to
  bottom; each prompt's `subject` is the full text sent, at its `size` (width, height).
  A prompt with a `base` is an edit of that approved picture; `animations` lists the
  animations made from it once it is approved.
  The queue is a copy of the live art tracker's prompts: when you change a prompt in
  the tracker, update it here too (or ask Claude to re-copy the tracker).
- **Make a prompt again:** on the `art-drafts` branch, delete its key (for example
  `"NP-02-1"`) from `"done"` in `progress.json`. A prompt that failed 3 times is skipped
  until you delete it from `"failures"`.
- **Time of day:** the `cron` line in the workflow (UTC).

## Limits
- New pictures use PixelLab's PixFlux model; edits of an approved picture use
  `edit-image-pixen` (falling back to `edit-image`), 8 directions
  `generate-8-rotations-v3`, animations `animate-with-text-v3` (8 frames). Edits,
  rotations and animations may cost more than one generation; the run log shows the
  balance before each run.
- Each animation is made from the approved south-east picture only; animations for the
  other 7 directions aren't queued yet.
- When PixelLab says the day's generations are used up, the bot stops and tries the
  rest tomorrow.

## Run it on your own computer
`python tools/art_bot/art_bot.py --drafts <folder> --dry-run` lists the next prompts.
Without `--dry-run`, set `PIXELLAB_SECRET` first.
