# contributing

contributing is anything from a pull request to an issue or a suggestion, all contributions are welcome!

## where to start

- check out [TODO.md](./TODO.md) for plans and pick an issue
- open an issue on github and fork
- create branch on your fork by doing

```bash
git checkout -b <issue_number>-<issue_description>
```

- after you have implemented fully the issue, make a pull request

```bash
git add .
git commit -m "Fixed #<issue_number>: <issue_description>"
git push origin <issue_number>-<issue_description>
```

- if you're adding an std function, please add a doc-comment that can get parsed by `scripts/docgen.py`

## about AI-generated code

please do not submit LLM-authored code if you do not understand it, can't explain it or have not tested it.
describe the request in your own words, rather than pulling in a wall of AI-generated text.
this greatly reduces maintenance burden.

thank you for considering contributing to revo!
