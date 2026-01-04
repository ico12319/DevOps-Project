package album

import (
	"github.com/ico12319/devops-project/internal/auth"
	"github.com/ico12319/devops-project/internal/entity"
	"github.com/ico12319/devops-project/internal/test"
	"github.com/ico12319/devops-project/pkg/log"
	"net/http"
	"testing"
	"time"
)

func TestAPI(t *testing.T) {
	logger, _ := log.NewForTest()
	router := test.MockRouter(logger)
	repo := &mockRepository{items: []entity.Album{
		{ID: "123", Name: "album123", CreatedAt: time.Now(), UpdatedAt: time.Now()},
	}}
	RegisterHandlers(router.Group(""), NewService(repo, logger), auth.MockAuthHandler, logger)
	header := auth.MockAuthHeader()

	tests := []test.APITestCase{
		{Name: "get all", Method: "GET", URL: "/albums", Body: "", Header: nil, WantStatus: http.StatusOK, WantResponse: `*"total_count":1*`},
		{Name: "get 123", Method: "GET", URL: "/albums/123", Body: "", Header: nil, WantStatus: http.StatusOK, WantResponse: `*album123*`},
		{Name: "get unknown", Method: "GET", URL: "/albums/1234", Body: "", Header: nil, WantStatus: http.StatusNotFound, WantResponse: ""},
		{Name: "create ok", Method: "POST", URL: "/albums", Body: `{"name":"test"}`, Header: header, WantStatus: http.StatusCreated, WantResponse: "*test*"},
		{Name: "create ok count", Method: "GET", URL: "/albums", Body: "", Header: nil, WantStatus: http.StatusOK, WantResponse: `*"total_count":2*`},
		{Name: "create auth error", Method: "POST", URL: "/albums", Body: `{"name":"test"}`, Header: nil, WantStatus: http.StatusUnauthorized, WantResponse: ""},
		{Name: "create input error", Method: "POST", URL: "/albums", Body: `"name":"test"}`, Header: header, WantStatus: http.StatusBadRequest, WantResponse: ""},
		{Name: "update ok", Method: "PUT", URL: "/albums/123", Body: `{"name":"albumxyz"}`, Header: header, WantStatus: http.StatusOK, WantResponse: "*albumxyz*"},
		{Name: "update verify", Method: "GET", URL: "/albums/123", Body: "", Header: nil, WantStatus: http.StatusOK, WantResponse: `*albumxyz*`},
		{Name: "update auth error", Method: "PUT", URL: "/albums/123", Body: `{"name":"albumxyz"}`, Header: nil, WantStatus: http.StatusUnauthorized, WantResponse: ""},
		{Name: "update input error", Method: "PUT", URL: "/albums/123", Body: `"name":"albumxyz"}`, Header: header, WantStatus: http.StatusBadRequest, WantResponse: ""},
		{Name: "delete ok", Method: "DELETE", URL: "/albums/123", Body: ``, Header: header, WantStatus: http.StatusOK, WantResponse: "*albumxyz*"},
		{Name: "delete verify", Method: "DELETE", URL: "/albums/123", Body: ``, Header: header, WantStatus: http.StatusNotFound, WantResponse: ""},
		{Name: "delete auth error", Method: "DELETE", URL: "/albums/123", Body: ``, Header: nil, WantStatus: http.StatusUnauthorized, WantResponse: ""},
	}
	for _, tc := range tests {
		test.Endpoint(t, router, tc)
	}
}
