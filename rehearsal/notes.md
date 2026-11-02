# Notes: things in the deck and its notes to look at

Found while writing the script. Nothing here was changed; the slides, notes.yaml and questions.md are as delivered.

## Timing

1. **Two plans.** The deck's notes plan 40:00 for the talk (notes.yaml), and questions.md still says "About 5 minutes are left for questions (40:00 planned)". The new session plan is 35:00 talk plus 8:00 Q&A. The script scales every slide's planned time by 35/40 and fits the text to it at 135 words per minute.
2. **The 40:00 plan assumes a slower pace than 135 words per minute.** notes.yaml has 4 529 words of notes for the 47 talk slides, and its planned times add up to 40:00: that is 113 words per minute, pauses and the demo included. It is the pace the plan was written for, not a measurement of how fast you speak. At 135 words per minute the script fits 35:00; your first timed run will show your real pace. If it runs long, the five SKIP slides (16, 24, 32, 37, 41) are 4:12 of speech in the script.
3. **Notes longer than their slot at 135 words per minute** (words in notes.yaml, against the scaled target). The script shortens them; your own delivery may not:
   - 3 "Ludwig Weinzierl": 121 words for 35 s
   - 9 "Burn 0.22 moved the backend": 154 words for 61 s
   - 12 "One matrix product: Burn": 111 words for 44 s
   - 14 "Wrong shapes: Burn panics": 116 words for 44 s
   - 15 "Wrong rank": 126 words for 44 s
   - 26 "Learning, in four lines": 136 words for 52 s
   - 31 "Same start, same data, same curve": 166 words for 61 s
   - 34 "Four steps": 147 words for 52 s
   - 37 "Two things std would have given": 143 words for 52 s
   - 39 "Someone else's model": 163 words for 66 s
   - 40 "The same model on a real chip": 61 words for 22 s, plus the board handover
4. **Slide 42, live demo.** The demo time is not in the notes. The script reserves 20 s; the fallback video `keywords.mp4` is 25 s.

## Content

5. **Slide 4** says part 3 is "Burn on an emulated microcontroller". Since the board slide, part 3 ends on a real chip. "Burn on a microcontroller" would cover both.
6. **Section numbers and parts.** The dividers are numbered 01 to 06, but the talk calls 03, 04 and 05 "part one, two, three" (matching the 1, 2, 3 on slide 4). On screen it says "03" while you say "part one". The script follows your notes; consider dropping the numbers from the dividers or saying "section three".
7. **Slide 47 notes** say "Three backup slides follow this one". There are four now, with "Grazie, Cava".
8. **Slide 9 notes** say Burn 0.22 came out "three weeks ago". On 2 November it is almost four weeks; the script says "on the 6th of October".
9. **Slide 7** says 0.11.0, the version that ran. Candle 0.11.1 came out on 31 October; someone may mention it. The script says "I used 0.11.0".
10. **Slide 40.** If the board goes round at this slide, you need a few seconds more than its 22 s, and the slide could show where the board's photo is, or say "it's going round". Optional.

## questions.md

11. **Question 55** ("What about power consumption?") still answers "there was no hardware run". Since 1 November there was one; power was still not measured.
12. **"How to answer"** still plans 5 minutes and "Two or three questions" (40:00 talk). With the new plan it's 8 minutes and about five questions.

## Pronunciation to confirm

13. **Tracel AI**: the script assumes "TRAY-sell". I could not confirm it; if you know how the company says it, change pronunciation.md before step 2.
14. **"no_std" and "std"**: "no stood" and "stood", as you say it (changed in pronunciation.md).
