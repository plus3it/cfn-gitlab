# Background 

This project is part of a larger collection of projects. The project-collection is geared towards automating the deployement of common DevOps Tool-Chain (DOTC) components into AWS. While there are many such projects out there, this particular project-set is geared towards deploying these tools in an as STIG-compatible manner possible. This means that the automation includes the "bits" necessary to harden an EL7 instance while providing the requisite hardening-exceptions necessary to allow the tool-elements to run within a hardened EL7-based environment.

# How to Contribute

Because of the above background, specific design decisions were made around the tools' deployments.

It would be great if users of this project could help by identifying gaps that our specific use-cases have not uncovered. In an ideal world, that help would come in the form of code-contributions (via pull-requests). Next-best option is submitting Issues identifying gaps with as great of detail as possible - preferably inclusive of suggestions for mitigating those gaps.

In the interest of full disclosure, the fruits of this automation-effort are openly provided on a wholly "as-is" basis. Individuals who have stumbled on this project and find deficiencies in it are invited to help us enhance the project for broader usability (as described above).

## Testing

This project leverages a fairly bare-bones test-suite performed through Travis CI's [online testing framework](https://travis-ci.org/). As of this contribution-guideline document's last edit date, the only things being tested for are templates' JSON validity and de-linting for shell (BASH) style and syntax checking.

JSON validity is determined with a quick pass through the JQ utility. Validity is a simple pass/fail test. Templates are not otherwise automatically tested for correct funtioning within AWS.

Shell style- and syntax-checking are done via [Koalaman's shellcheck utilities](https://github.com/koalaman/shellcheck) (functionality which is also available via copy/paste at https://www.shellcheck.net/). The current test "recipies" are found in the `.travis.yml` file found in the project's root directory.

## Submitting Changes

In general, we prefer changes be offered in the form of tested pull-requests. Prior to opening a pull-request, we also prefer that an associated issue be opened - you can request that you be assigned or otherwise granted ownership in that issue. The submitted pull-request should reference the previously-opened issue. The pull-request should include a clear list of what changes are being offered (read more about [pull requests](http://help.github.com/pull-requests/)). The received PR should show green in Travis (see the above "Testing" section). If the received PR doesn't show green in Travis, it will be rejected. It is, therefore, recommended that prior to submitting a pull request, Travis will have been leveraged to pre-validate changes in the submitter's fork.

Feel free to enhance the Travis-based checks as desired. Modifications to the `.travis.yml` received via a PR will be evaluated for inclusion as necessary. If other testing frameworks are preferred, please feel free to add them via a PR ...ensuring that the overall PR still passes the existing Travis CI framework. Any way you slice it, improvements in testing are great. We would be very glad of receiving and evaluating any testing-enhancements offered.

Please ensure that commits included in the PR are performed with both clear and concise commit messages. One-line messages are fine for small changes. However, bigger changes should look like this:

    $ git commit -m "A brief summary of the commit
    >
    > A paragraph describing what changed and its impact."

## Coding conventions

Start by reading the existing code. Things are fairly straight-forward - or at least as straight-forward as BASH can be fore certain types of tasks.  We optimize for narrower terminal widths - typically 80-characters (the individual who originated the project has some ooooold habits) but sometimes 120-character widths may be found. We also optimize for UNIX-style end-of-line. Please ensure that your contributions line-ends use just a line-feed (lf) rather than a Windows-style carriage-return/line-feed (crlf) end-of-line. Note that the project-provided `.editorconfig` file should help ensure this behavior.

Overall, shell script conventions are fairly minimal
    * Pass the shellchecker validity tests
    * Use three-space indent-increments for basic indenting
    * If breaking across lines, indent following lines by two-spaces (to better differentiate from standard indent-blocks) - obviously, this can be ignored for here-documents..
    * Code should be liberally-commented.
       * Use "# " or "## " to prepend.
       * Indent comment-lines/blocks to line up with the blocks of code being commented
    * Anything not otherwise specified - either explicitly as above or implicitly via pre-existing code - pick an element-style and be consistent with it.
