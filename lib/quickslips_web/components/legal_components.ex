defmodule QuickSlipsWeb.LegalComponents do
  @moduledoc """
  The words of the legal pages: the terms of use, the privacy policy and the disclaimer (`QuickSlipsWeb.LegalLive`).

  They are plain-language drafts that say what QuickSlips really does, and they must stay in step with the code: a
  cookie that is added, a service provider that is used, a thing that is kept longer or shorter, is a change of the
  text (and of its date). The wording itself is a legal matter, and a lawyer should read it before the pages are
  relied on. Left out on purpose, because they are the owner's to decide: the law that governs the terms, a
  company name, named contacts that some countries ask for, and how long logs are kept.

  The pages are in English only. The contact address is the owner's (`QuickSlips.Site.contact_email/0`), and a
  sentence that needs one is left out when there is none.
  """
  use QuickSlipsWeb, :html

  # What the text of a page looks like, set on the page and applied to what is inside it, so the text below is
  # plain paragraphs and lists.
  @prose [
    "[&_p]:text-base/7 [&_p]:text-ink [&_ul]:list-disc [&_ul]:space-y-2 [&_ul]:pl-6",
    "[&_li]:text-base/7 [&_li]:text-ink [&_li]:marker:text-ink-faint",
    "[&_a]:rounded-field [&_a]:font-medium [&_a]:text-primary [&_a]:underline [&_a]:underline-offset-2",
    "[&_a]:focus-visible:outline-2 [&_a]:focus-visible:outline-offset-2 [&_a]:focus-visible:outline-focus",
    "[&_code]:rounded [&_code]:bg-surface-muted [&_code]:px-1.5 [&_code]:py-0.5 [&_code]:text-sm [&_code]:text-ink"
  ]

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :updated, Date, required: true, doc: "when the text last changed"
  slot :inner_block, required: true

  defp legal_page(assigns) do
    assigns = assign(assigns, :prose, @prose)

    ~H"""
    <article id={@id} class={@prose}>
      <h1 class="font-display text-3xl font-bold tracking-tight text-ink">{@title}</h1>
      <p id={"#{@id}-updated"} class="mt-2 !text-sm/6 !text-ink-muted">
        Last updated: {Calendar.strftime(@updated, "%-d %B %Y")}
      </p>
      <div class="mt-8 space-y-9">{render_slot(@inner_block)}</div>
    </article>
    """
  end

  attr :title, :string, required: true
  slot :inner_block, required: true

  defp legal_section(assigns) do
    ~H"""
    <section class="space-y-3">
      <h2 class="font-display text-xl font-semibold tracking-tight text-ink">{@title}</h2>
      {render_slot(@inner_block)}
    </section>
    """
  end

  attr :email, :string, default: nil

  defp mail_link(assigns) do
    ~H"""
    <a href={"mailto:" <> @email}>{@email}</a>
    """
  end

  # The way in to the contact form, inside a sentence. Only the sentences that are shown when there is an address
  # to send to use it, and the form is there when there is one.
  defp contact_link(assigns) do
    ~H"""
    <.link navigate={~p"/contact"}>contact form</.link>
    """
  end

  ## The terms of use

  attr :contact_email, :string, default: nil

  def terms(assigns) do
    ~H"""
    <.legal_page id="legal-terms" title="Terms of use" updated={~D[2026-11-13]}>
      <p>
        These terms are the rules for using QuickSlips, a website that helps you make bills and receipts as PDF files.
        By using QuickSlips you agree to them. If you do not agree, please do not use the site.
      </p>

      <.legal_section title="What QuickSlips does">
        <p>
          You fill in a form, QuickSlips draws a document from the details you enter, and you download it as a PDF.
          It is a tool for writing down real transactions. It does not check what you enter, and the documents it
          makes are not official invoices or tax documents. We turn the details you enter into ready-to-use documents;
          it is up to you to double-check that everything is accurate and used lawfully, and these documents are not
          meant for legal use without a lawyer's review. Please read the <.link navigate={
            ~p"/disclaimer"
          }>Disclaimer</.link>.
        </p>
      </.legal_section>

      <.legal_section title="Using QuickSlips">
        <p>
          You may use QuickSlips for your own personal and business documents, free of charge, within the daily
          limits shown on the page. When you use it, you agree that you will:
        </p>
        <ul>
          <li>
            make documents only for transactions that really happened, with true amounts, dates and names;
          </li>
          <li>
            not forge, falsify or alter any document, and not use QuickSlips to mislead a tax authority, an
            employer, a landlord, a bank, an insurer or anyone else, or to commit fraud;
          </li>
          <li>only enter details, logos and pictures that you have the right to use;</li>
          <li>
            not try to get around the daily limits or the checks that tell people from bots, not download in bulk
            with scripts, not look for weaknesses in the site and not overload it; and
          </li>
          <li>follow the laws that apply to you.</li>
        </ul>
      </.legal_section>

      <.legal_section title="Your account">
        <p>
          You can use QuickSlips without an account. With an account you can save businesses, logos and signatures,
          keep a history of your documents and download more each day. You can sign up with an e-mail address and a
          password, with a link sent to your e-mail, or with Google.
        </p>
        <p>
          Give a real e-mail address, keep your password and your log-in links to yourself, and tell us if you think
          someone else has used your account. You are responsible for what happens under your account.
        </p>
      </.legal_section>

      <.legal_section title="Your content">
        <p>
          The details you enter, your logos and your signature pictures belong to you. You allow us to process them
          only as far as needed to run QuickSlips for you: to draw your PDFs, to keep what you choose to save, and to
          protect the service from misuse. We do not publish your documents, we do not sell your data and we do not
          use it for advertising. The <.link navigate={~p"/privacy"}>Privacy policy</.link>
          explains the details.
        </p>
      </.legal_section>

      <.legal_section title="Limits, changes and availability">
        <p>
          Free downloads are limited each day, and the page shows how many you have left. We may change the limits,
          change or remove templates, add paid features or stop the service. If we add paid features, we will tell
          you before you pay for anything.
        </p>
        <p>
          We try to keep QuickSlips available and correct, but we do not promise that it will always work or that it
          will be free of mistakes.
        </p>
      </.legal_section>

      <.legal_section title="Our rights in the site">
        <p>
          QuickSlips, its templates, its texts and its software belong to us or to the people who license them to us.
          The documents you make are yours to use for their purpose. Please do not copy, resell or republish the
          site, its templates or its software.
        </p>
      </.legal_section>

      <.legal_section title="No warranty">
        <p>
          QuickSlips is provided “as it is” and “as available”. As far as the law allows, we make no promise that
          the documents are correct, complete or suitable for a particular purpose, or that anyone will accept them.
        </p>
      </.legal_section>

      <.legal_section title="Our responsibility">
        <p>
          As far as the law allows, we are not responsible for losses that come from how you use a document, from
          mistakes in what you or anyone else entered, from changes in tax rules, or from the site being
          unavailable. Nothing in these terms limits a responsibility that the law does not allow us to limit.
        </p>
      </.legal_section>

      <.legal_section title="Ending your use">
        <p>
          You can stop using QuickSlips at any time. We may limit or close an account, or block access, if you break
          these terms, misuse the service or put it or other people at risk.
        </p>
        <p :if={@contact_email}>
          To close your account and have your data deleted, use the <.contact_link /> or write to
          <.mail_link email={@contact_email} />.
        </p>
      </.legal_section>

      <.legal_section title="Changes to these terms">
        <p>
          We may change these terms. The date at the top shows when they last changed. If you keep using QuickSlips
          after a change, you accept the new terms. If a change matters a lot, we will say so on the site or by
          e-mail.
        </p>
      </.legal_section>

      <.legal_section :if={@contact_email} title="Contact">
        <p>
          Questions about these terms? Use the <.contact_link /> or write to
          <.mail_link email={@contact_email} />.
        </p>
      </.legal_section>
    </.legal_page>
    """
  end

  ## The privacy policy

  attr :contact_email, :string, default: nil

  def privacy(assigns) do
    ~H"""
    <.legal_page id="legal-privacy" title="Privacy policy" updated={~D[2026-11-13]}>
      <p>
        This page says what QuickSlips does with information about you. We have tried to keep it short and to say
        only what is true.
      </p>

      <.legal_section title="The short version">
        <ul>
          <li>
            You can make documents without an account. What you type is used to draw your PDF, and we do not keep it.
          </li>
          <li>
            With an account we keep your e-mail address, the businesses and signatures you save and a history of your
            documents, so that you can use them again.
          </li>
          <li>
            We use Google Analytics to count visits and to see which pages are used. It uses cookies. It
            starts only if you agree, and you can change your mind at any time.
          </li>
          <li>
            We do not sell your data, we show no advertising and we use no advertising trackers.
          </li>
          <li>
            You can delete your documents, saved businesses and signatures yourself. For anything else, write to us.
          </li>
        </ul>
      </.legal_section>

      <.legal_section title="Who we are">
        <p>
          QuickSlips is run by the people behind this website, called “we” on this page.
          <span :if={@contact_email}>
            You can reach us through the <.contact_link /> or at
            <.mail_link email={@contact_email} />.
          </span>
        </p>
      </.legal_section>

      <.legal_section title="What we collect, and why">
        <p>
          <strong>Everyone who visits.</strong>
          Like any website, our servers see your IP address, the pages you ask for, the time, and the type of browser
          and device you use. We use this to show you the site, to keep it secure and to find faults, and we keep
          technical logs for a limited time. Cloudflare tells us the country your visit comes from, and your browser
          tells us its language; we use both only to suggest a language and country for the site.
        </p>
        <p id="legal-visit-statistics">
          <strong>Visit statistics.</strong>
          We use Google Analytics, loaded through Google Tag Manager, to count visits and to see which pages are
          used, so that we can improve the site. It records the pages you view, how far you scroll, the links to
          other sites that you click, the files you download, and when you start or send a form, but not what you
          type into a form. Google also receives your IP address, your browser, device and language, and works out
          roughly where you are from the IP address. It sets cookies for this, listed below. We use these statistics
          only to understand how the site is used, never for advertising. How Google handles this data is explained
          in <a
            href="https://policies.google.com/technologies/partner-sites"
            target="_blank"
            rel="noopener noreferrer"
          >How Google uses data when you use our partners' sites or apps</a>.
        </p>
        <p id="legal-consent">
          <strong>Your say in it.</strong>
          Nothing of Google's is loaded until you agree, in the banner that asks on your first visit, wherever you
          are. Your choice is kept in your browser, not in a cookie. You can
          change it at any time with “Cookie settings” in the footer, and we ask again after a year. If you say no, or
          change your mind, Google Analytics is told to stop, its cookies are deleted, and it does not start again on
          the next page you open.
        </p>
        <p>
          <strong>Daily download limits.</strong>
          To limit free downloads we keep a counter for each day. For a visitor without an account the counter is
          tied to a random identifier kept in a cookie and to the IP address; for someone who is logged in it is tied
          to the account. A visitor without an account also passes a check by Cloudflare (Turnstile) that tells
          people from bots; Cloudflare receives the result of the check and your IP address for that.
        </p>
        <p>
          <strong>Making a document.</strong>
          The preview is drawn in your browser and is not sent to us. When you download, the details you typed are
          sent to our server, which draws the PDF and sends it back. If you do not have an account, we do not keep
          those details or the PDF.
        </p>
        <p>
          <strong>Your account.</strong>
          If you sign up we keep your e-mail address and when you confirmed it. We keep your password only in a
          scrambled form that cannot be turned back into the password. If you sign in with Google, we keep your
          Google account identifier, your name and the link to your picture. We send you e-mails with log-in links
          and account messages, through an e-mail provider.
        </p>
        <p>
          <strong>What you save.</strong>
          Saved businesses (name, address, tax number and logo), signature pictures, and your document history: for
          each document you download while logged in, we keep the details you entered and the template you used, not
          the PDF, so that you can download it again or edit it. We keep your latest 200 documents and delete older
          ones automatically. Pictures you upload are kept in private storage and are shown only to you.
        </p>
        <p :if={@contact_email} id="legal-contact-messages">
          <strong>Messages you send us.</strong>
          If you use the contact form, we receive what you write: the kind of message, your e-mail address, your
          name if you give it, and your message. We also receive the language and country of the page you were on,
          the page you wrote about if you came from one, and, if you are logged in, the e-mail address of your
          account. We keep the message in our database, under a reference that we give you, so that we can find it
          again; we are told of it by e-mail, and we send a confirmation to the address you gave (it holds the
          reference, the kind of message, your name and your words). We use it only to read it and to answer you. Everybody
          who uses the form passes the Turnstile check described above, because the confirmation goes to the
          address that was typed. To limit abuse we count the messages sent each day, in all, for each logged-in
          account and for each address that a confirmation goes to; the count of an address is kept under a
          scrambled form of it, not under the address itself.
        </p>
        <p>
          <strong>Errors.</strong>
          When something breaks, we keep a technical report of where in the program it happened and what kind of
          error it was. What people typed, form data, passwords and one-time links are removed before it is stored.
        </p>
      </.legal_section>

      <.legal_section title="Cookies and similar storage">
        <p>
          These are needed for the site to work, to keep it secure and to remember your choices. We use no
          advertising cookies.
        </p>
        <ul id="legal-cookies">
          <li>
            <code>_quickslips_key</code>
            keeps you logged in, remembers the language of the last page you saw and protects forms from forgery. It
            lasts until you close the browser.
          </li>
          <li>
            <code>_quick_slips_web_user_remember_me</code>
            is set only if you choose to stay logged in, and lasts 14 days.
          </li>
          <li>
            <code>vid</code> is the random identifier for the daily download limit. It lasts one year.
          </li>
          <li>
            <code>qs_locale</code>
            remembers the language and country you chose. It is set only when you choose one, and lasts one year.
          </li>
          <li>
            Your browser also keeps your light or dark choice, your choice about the visit statistics,
            and copies of the preview engine and the fonts, so that pages load faster.
          </li>
          <li>
            Cloudflare, which sits in front of the site, may set its own cookies or similar storage for security.
          </li>
        </ul>
        <p>
          Google Analytics (see “Visit statistics” above) sets two more cookies, which the site does not need in order
          to work. They are set only if you agree. You can block them; see “Your choices and rights”.
        </p>
        <ul id="legal-analytics-cookies">
          <li>
            <code>_ga</code>
            tells one visitor from another, so that visits can be counted. It lasts up to two years.
          </li>
          <li>
            <code>_ga_</code>
            followed by a code of our Analytics account keeps the state of your visit. It lasts up to two years.
          </li>
        </ul>
      </.legal_section>

      <.legal_section title="Who else handles your data">
        <p>
          We use other companies to run QuickSlips: a hosting provider for our servers and database, Cloudflare to
          protect and speed up the site and for the Turnstile check, Google to count visits (Google Analytics), an
          e-mail provider to send log-in and account
          e-mails<span :if={@contact_email}>
            and to deliver the messages of the contact form to us and their confirmations to the people who wrote them
          </span>, and, only if you choose “Continue with Google”, Google to sign you in. They may handle data in
          other countries. We do not sell your data and we do not share it for advertising. We may share data if the
          law requires it.
        </p>
      </.legal_section>

      <.legal_section title="How long we keep it">
        <ul>
          <li>
            Your account and what you saved: until you delete it, or until your account is closed.
          </li>
          <li>Your document history: your latest 200 documents.</li>
          <li :if={@contact_email}>
            Messages from the contact form, in our database and in our mailbox: for as long as we need them to deal
            with your request and to keep a record of it. You can ask us to delete one.
          </li>
          <li>
            The daily counters and the technical logs: for as long as we need them to enforce the limits and to keep
            the service secure and working.
          </li>
          <li>
            Visit statistics: Google Analytics keeps the detailed data for 14 months at most.
          </li>
        </ul>
        <p :if={@contact_email}>
          If you ask us to close your account, we delete your account data and everything you saved. We may keep a
          short record where the law requires it or to prevent abuse.
        </p>
      </.legal_section>

      <.legal_section title="Your choices and rights">
        <p>
          In the app you can see, change and delete your saved businesses, signatures and documents, and you can log
          out at any time. Depending on where you live, you may also have the right to ask us for a copy of your
          data, to correct it, to delete it, or to object to how we use it, and to complain to your local data
          protection authority.
        </p>
        <p>
          <strong>Visit statistics.</strong>
          You can change your choice at any time with “Cookie settings” in the footer. You can also stop Google Analytics by blocking cookies and scripts in your browser, with a content blocker, or with <a
            href="https://tools.google.com/dlpage/gaoptout"
            target="_blank"
            rel="noopener noreferrer"
          >Google's opt-out add-on</a>. The site works the same without it.
        </p>
        <p :if={@contact_email}>
          To use these rights, or to close your account, use the <.contact_link /> or write to
          <.mail_link email={@contact_email} />.
        </p>
      </.legal_section>

      <.legal_section title="Security">
        <p>
          The site is served over encrypted (HTTPS) connections, passwords are stored in scrambled form and uploaded
          pictures are kept private. No system is perfectly secure, so please use a strong password, and tell us if
          you notice anything wrong.
        </p>
      </.legal_section>

      <.legal_section title="Children">
        <p>
          QuickSlips is for adults. It is not meant for children, and we do not knowingly collect their data.
        </p>
      </.legal_section>

      <.legal_section title="Changes to this policy">
        <p>
          We may change this policy. The date at the top shows when it last changed. If a change matters, we will say
          so on the site or by e-mail. See also the <.link navigate={~p"/terms"}>Terms of use</.link>.
        </p>
      </.legal_section>

      <.legal_section :if={@contact_email} title="Contact">
        <p>
          Questions about your data? Use the <.contact_link /> or write to
          <.mail_link email={@contact_email} />.
        </p>
      </.legal_section>
    </.legal_page>
    """
  end

  ## The disclaimer

  attr :contact_email, :string, default: nil

  def disclaimer(assigns) do
    ~H"""
    <.legal_page id="legal-disclaimer" title="Disclaimer" updated={~D[2026-11-13]}>
      <p>
        QuickSlips helps you write down things that really happened. Please read what a document made here is, and is
        not.
      </p>

      <.legal_section title="Check every document before you use it">
        <p>
          We turn the details you enter into ready-to-use documents. It is up to you to double-check that everything is
          accurate and used lawfully, and please remember that these documents are not meant for legal use without a
          lawyer's review.
        </p>
      </.legal_section>

      <.legal_section title="Not an official document">
        <p>
          A document made with QuickSlips is drawn from the details you enter. No tax authority, e-invoicing system,
          bank, employer, landlord or other body issues, checks or approves it. It does not replace an official
          invoice, tax invoice, e-invoice or fiscal receipt where the law requires one.
        </p>
      </.legal_section>

      <.legal_section title="Real transactions only, and you are responsible">
        <p>
          Use QuickSlips only to record transactions that really happened, with true amounts, dates and names. You
          are responsible for everything you enter and for how you use the document. Making or using a false or
          misleading document can be a crime and can have serious consequences, and we are not responsible for it.
        </p>
        <p>
          Some templates are made for things like rent, salary, leave travel or education allowance claims. Whether a
          document is accepted is decided by the person or body you give it to, not by us.
        </p>
      </.legal_section>

      <.legal_section title="No advice">
        <p>
          QuickSlips gives no tax, legal, accounting or financial advice. The tax names, rates and number formats
          shown for each country come from public sources and may be out of date or wrong for your case. Check them
          with the tax authority or an adviser before you rely on them.
        </p>
      </.legal_section>

      <.legal_section title="Translations and examples">
        <p>
          The site and the templates are available in several languages. The translations were made for convenience
          and may contain mistakes; where the exact words matter, check them yourself. The example details on the
          pages are made up and do not refer to real people or businesses.
        </p>
      </.legal_section>

      <.legal_section title="Names of companies and documents">
        <p>
          Names of kinds of companies and documents (fuel stations, hotels, couriers, internet providers and so on)
          are used only to describe the kind of document. QuickSlips is not connected with, and is not endorsed by,
          any company, brand or authority.
        </p>
      </.legal_section>

      <.legal_section title="More">
        <p>
          The <.link navigate={~p"/terms"}>Terms of use</.link>
          set out the rules and our responsibility, and the
          <.link navigate={~p"/privacy"}>Privacy policy</.link>
          says what we do with your data.
        </p>
      </.legal_section>

      <.legal_section :if={@contact_email} title="Contact">
        <p>Questions? Use the <.contact_link /> or write to <.mail_link email={@contact_email} />.</p>
      </.legal_section>
    </.legal_page>
    """
  end
end
