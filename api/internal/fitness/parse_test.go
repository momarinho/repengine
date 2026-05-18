package fitness

import "testing"

func TestFirstNumberString(t *testing.T) {
	tests := []struct {
		name   string
		input  string
		want   float64
		wantOK bool
	}{
		{name: "plain integer", input: "100", want: 100, wantOK: true},
		{name: "value with unit", input: "102.5 kg", want: 102.5, wantOK: true},
		{name: "negative decimal", input: "-2.5%", want: -2.5, wantOK: true},
		{name: "no number", input: "bodyweight", want: 0, wantOK: false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, ok := FirstNumberString(tt.input)
			if ok != tt.wantOK {
				t.Fatalf("expected ok=%v, got %v", tt.wantOK, ok)
			}
			if got != tt.want {
				t.Fatalf("expected %v, got %v", tt.want, got)
			}
		})
	}
}

func TestOptionalFirstNumberString(t *testing.T) {
	if got := OptionalFirstNumberString("bodyweight"); got != nil {
		t.Fatalf("expected nil for non-numeric input, got %#v", got)
	}

	got := OptionalFirstNumberString("8.5")
	value, ok := got.(float64)
	if !ok {
		t.Fatalf("expected float64, got %T", got)
	}
	if value != 8.5 {
		t.Fatalf("expected 8.5, got %v", value)
	}
}
