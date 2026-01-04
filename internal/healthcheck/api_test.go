package healthcheck

import (
	"github.com/ico12319/devops-project/internal/test"
	"github.com/ico12319/devops-project/pkg/log"
	"net/http"
	"testing"
)

func TestAPI(t *testing.T) {
	logger, _ := log.NewForTest()
	router := test.MockRouter(logger)
	RegisterHandlers(router, "0.9.0")
	test.Endpoint(t, router, test.APITestCase{
		Name: "ok", Method: "GET", URL: "/healthcheck", Body: "", Header: nil, WantStatus: http.StatusOK, WantResponse: `"OK 0.9.0"`,
	})
}
