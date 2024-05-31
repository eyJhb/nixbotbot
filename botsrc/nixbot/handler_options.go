package nixbot

import (
	"bytes"
	"context"
	"html"
	"sort"
	"text/template"

	"github.com/adrg/strutil"
	"github.com/adrg/strutil/metrics"
	"maunium.net/go/mautrix"
	"maunium.net/go/mautrix/event"
)

var (
	tmplNixOptions = template.Must(template.New("nix-options").Parse(`
{{- range $v := .}}
- [{{html $v.Name}}](https://search.nixos.org/options?channel=unstable&query={{$v.Name}})
{{- end -}}
`))

	tmplNixOption = template.Must(template.New("nix-option").Parse(`
**Name**: {{html .Name}}

**Description**: {{.NixOption.Description}}

**Type**: {{.NixOption.Type}}

**Default**:
` + "```nix" + `
{{.NixOption.Default.Text}}
` + "```" + `

**Example**:
` + "```nix" + `
{{.NixOption.Example.Text}}
` + "```" + `

**Declared in** [{{ (index .NixOption.Declarations 0).Name }}]({{ (index .NixOption.Declarations 0).URL }})

			`))
	// **Options page** [NixOS Options](https://search.nixos.org/options?channel=unstable&query={{.Name}})
)

func (nb *NixBot) CommandHandlerSearchOptions(ctx context.Context, client *mautrix.Client, evt *event.Event) error {
	vars := nb.vars(ctx)
	search := vars["search"]
	hm := vars["hm"]

	// fetch the correct set of options
	var err error
	var nixOptions map[string]NixOption
	if hm != "" {
		nixOptions, err = nb.FetchHomeManagerOptions(ctx)
	} else {
		nixOptions, err = nb.FetchNixOSOptions(ctx)
	}
	if err != nil {
		return err
	}

	filteredOptions := nb.NixOptionsFuzzySearch(search, nixOptions, 10)

	// execute template
	var buf bytes.Buffer
	err = tmplNixOptions.Execute(&buf, filteredOptions)
	if err != nil {
		return err
	}

	return nb.SendMarkdownReply(ctx, client, evt, buf.Bytes())
}

func (nb *NixBot) CommandHandlerSearchOption(ctx context.Context, client *mautrix.Client, evt *event.Event) error {
	vars := nb.vars(ctx)
	search := vars["search"]
	hm := vars["hm"]

	var err error
	var nixOptions map[string]NixOption
	if hm != "" {
		nixOptions, err = nb.FetchHomeManagerOptions(ctx)
	} else {
		nixOptions, err = nb.FetchNixOSOptions(ctx)
	}
	if err != nil {
		return err
	}

	filteredOption := nb.NixOptionsFuzzySearch(search, nixOptions, 1)[0]

	var buf bytes.Buffer
	err = tmplNixOption.Execute(&buf, filteredOption)
	if err != nil {
		return err
	}

	return nb.SendMarkdownReplySummary(ctx, client, evt, buf.Bytes(), html.EscapeString(filteredOption.Name))
}

func (nb *NixBot) NixOptionsFuzzySearch(search string, nixOptions map[string]NixOption, limit int) []NixOptionName {
	// fuzzy search all the options
	var nixOptionKeys []NixOptionName
	for k, v := range nixOptions {
		nixOptionKeys = append(nixOptionKeys, NixOptionName{Name: k, NixOption: v})
	}

	sort.Slice(nixOptionKeys, func(i, j int) bool {
		s1 := strutil.Similarity(search, nixOptionKeys[i].Name, metrics.NewSmithWatermanGotoh())
		s2 := strutil.Similarity(search, nixOptionKeys[j].Name, metrics.NewSmithWatermanGotoh())
		return s1 > s2
	})

	if limit > len(nixOptionKeys) {
		return nixOptionKeys
	}

	return nixOptionKeys[:limit]
}
