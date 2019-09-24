<template>
  <div id="finder-app">
    <div class="filter-by">
      <div class="search">
        <input
          id="search-bar"
          v-model="search"
          class="search-field"
          type="text"
          placeholder="Search by license holder, company, or #"
          @keyup.enter="filter()"
        >
        <input
          ref="archive-search-bar"
          type="submit"
          class="search-submit"
          value="Search"
          @click="filter()"
        >
        <button
          v-if="search.length > 0"
          class="clear-search-btn"
          @click="clearSearchBar"
        >
          <i class="fas fa-times " />
        </button>
      </div>
      <div class="select-license-type">
        <v-select
          ref="contractorSelect"
          v-model="licenseType"
          label="license_type"
          placeholder="All contractor types"
          :options="lTypesCounts"
        />
      </div>
    </div>
    <div
      v-show="loading"
      class="mtm center"
    >
      <i class="fas fa-spinner fa-spin fa-3x" />
    </div>
    <div
      v-show="!loading && emptyResponse"
      class="h3 mtm center"
    >
      Sorry, there are no results.
    </div>
    <div
      v-show="failure"
      class="h3 mtm center"
    >
      Sorry, there was a problem. Please try again.
    </div>
    <div
      v-if="!loading && !emptyResponse && !failure"
      class="table-container"
    >
      <table
        v-if="filteredLicenses.length"
        data-sticky-container
      >
        <thead
          class="center"
        >
          <tr>
            <th class="license-holder-title">
              <span>License Holder</span>
            </th>
            <th 
              v-if="!isMobile()"
              class="company-name"
            >
              <span>Company Name</span>
            </th>
            <th 
              v-if="specialCategories && !isMobile()"
              class="special-categories"
            >
              <span>Special Inspection Categories</span>
            </th>
            <th 
              v-if="!isMobile()"
              class="contractor-type"
            >
              <span>Contractor Type</span>
            </th>
            <th class="license-number">
              <span>License #</span>
            </th>
          </tr>
        </thead>
        <!-- <tbody> -->
        <paginate
          name="filteredLicenses"
          :list="filteredLicenses"
          class="paginate-list"
          tag="tbody"
          :per="50"
        >
          <tr
            v-for="license in paginated('filteredLicenses')"
            :key="license.licensenumber"
            class="license-row" 
          >
            <td
              class="license-holder"
            >
              {{ license.contactname | upperCase }}
            </td>
            <td
              v-if="!isMobile()"
              class="company-name"
            >
              {{ license.companyname | upperCase }}
            </td>
            <td
              v-if="specialCategories && !isMobile()"
              class="special-categories"
            >
              {{ license.icccategory }}
            </td>
            <td
              v-if="!isMobile()"
              class="contractor-type"
            >
              {{ license.licensetype | titleCase }}
            </td>
            <td
              class="license-number"
            >
              {{ license.licensenumber }}
            </td>
          </tr>
        </paginate>
        <!-- </tbody> -->
      </table>
      <div class="app-pages">
        <p> Showing <b> {{ numberOf }} </b> contractors </p>
        <paginate-links
          v-show="!loading && !emptyResponse && !failure"
          for="filteredLicenses"
          :async="true"
          :limit="3"
          :show-step-links="true"
          :hide-single-page="true"
          :step-links="{
            next: 'Next',
            prev: 'Previous'
          }"
          @change="scrollToTop()"
        />
      </div>
    </div>
  </div>
</template>

<script>
import Vue from "vue";
import axios from "axios";
import vSelect from 'vue-select';
import VuePaginate from "vue-paginate";
import VueFuse from "vue-fuse";
import VueAnalytics from "vue-analytics";

Vue.use(VuePaginate);
Vue.use(VueFuse);
Vue.use(VueAnalytics, {
  id: 'UA-860026-1',
  debug: {
    enabled: process.env.NODE_ENV === 'development',
    sendHitTask: process.env.NODE_ENV === 'production',
  },
});

const serviceURL = "https://data.phila.gov/carto/api/v2/sql?q=";
const query_base = "SELECT contactname, companyname, icccategory, licensenumber, licensetype FROM li_trade_licenses WHERE licensestatus = 'ACTIVE'";
const query_licensetypes = "SELECT DISTINCT licensetype FROM li_trade_licenses";

export default {
  name: "FindALicensedContractor",
  components: { 
    vSelect,
  },
  filters: {
    'upperCase': function(value) {
      if (value) {
        return value.toUpperCase().trim();
      }
    },

    'titleCase': function(str) {
      return str.replace(/\w\S*/g, function(txt){
        return txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase();
      });
    },
  },
  data: function() {
    return {
      search: '',
      licenseType: '',
      licenses: {},
      licenseTypes: [],
      lTypesCounts: [],
      filteredLicenses: [],
      sortedLicenses: [],
      loading: true,
      emptyResponse: false,
      failure: false,
      specialCategories: false,
      paginate: [ 'filteredLicenses' ],
      searchOptions: {
        shouldSort: false,
        threshold: 0.2, 
        keys: [
          'contactname',
          'companyname',
          'icccategory',
          'licensenumber',
        ],
      },
      contractorOptions: {
        shouldSort: false, 
        threshold: 0.0, 
        keys: [
          'licensetype',
        ],
      },
      routerQuery: {},
    };
  },
  computed: { 
    numberOf : function() {
      return this.filteredLicenses.length;
    },
  },

  watch: {
    licenseType: function(value) {
      //split string if it exists, otherwise send null/empty val to delete from router
      let val = value ? value.split(" (")[0] : value;  
      this.filter();
      this.updateRouterQuery('licenseType', val);
    },

    search: function(value) {
      this.filter();
      if (value.length > 3) {
        this.updateRouterQuery('search', value);
      } else {
        this.updateRouterQuery('search', null);
      }
    },
    
    loading : function(val) {
      if (val === false) {
        this.countLicenses();
      }
    },

    routerQuery: {
      handler: function () {
        this.updateRouter();
      },
      deep: true,
    },

  },

  mounted: async function() {
    this.getAllLicenses();
    this.getLicenseTypes();
  },

  methods: {
    getAllLicenses: function() {
      {
        axios
          .get(serviceURL+query_base)
          .then(response => {
            this.licenses = response.data;

            //sorted alphabetically by name
            this.sortedLicenses = this.licenses.rows.sort(function(a, b) {
              if (a.contactname === b.contactname) {
                return 0;
              } else if (a.contactname === null) {
                return 1;
              } else if (b.contactname === null) {
                return -1;
              } 
              return a.contactname.toLowerCase().trim() < b.contactname.toLowerCase().trim() ? -1 : 1;
            });

            // sorted by license number
            // this.sortedLicenses = this.licenses.rows.sort(function (a, b) {
            //   return a.licensenumber - b.licensenumber;
            // });

            this.filteredLicenses = this.sortedLicenses;
            this.loading = false;
          })
          .catch(e => {
            window.console.log(e);
            this.failure = true;
            this.loading = false;
          }).finally(() => {
            this.initFilters();
          });
      }
    },

    getLicenseTypes: function() {
      {
        axios
          .get(serviceURL+query_licensetypes)
          .then(response => {
            this.licenseTypes = response.data.rows;
            this.licenseTypes = this.licenseTypes.map(function(x) {
              return (x.licensetype);
            }).sort();
          })
          .catch(e => {
            window.console.log(e);
          });
      }
    },

    countLicenses: function() {
      this.lTypesCounts = [];
      this.licenseTypes.forEach((category)=> {
        let categoryCount = this.filteredLicenses.filter(license => license.licensetype === category).length;
        this.lTypesCounts.push(this.toTitleCase(category) + " (" +  categoryCount + ")");  
      });
    }, 

    filterBySearch: function () {
      if (this.search) {
        this.$search(this.search, this.filteredLicenses, this.searchOptions).then(licenses => {
          this.filteredLicenses = licenses;
        }); 
      } 
    },

    filterByType: function() {
      if (this.licenseType) {

        let categoryNoCount = this.licenseType.split(" (")[0];
        //only add special categories column if these are selected, or all contractors are selected
        this.$search(categoryNoCount, this.filteredLicenses, this.contractorOptions).then(licenses => {
          this.filteredLicenses = licenses;
        });
      } 
    },

    filter: async function() {
      this.filteredLicenses = this.sortedLicenses;
      this.specialCategories = false;
      await this.filterBySearch();
      await this.filterByType();
      await this.checkEmpty();
      await this.scrollToTop();
    },

    toTitleCase: function(str) {
      if (str){
        return str.replace(/\w\S*/g, function(txt){
          return txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase();
        });
      }
    },

    checkEmpty: function() {
      this.emptyResponse = (this.filteredLicenses.length === 0);
      
      this.specialCategories = (this.search === "" && (this.licenseType === null || this.licenseType === "") ? false : 
        (this.filteredLicenses.filter(function(license) {
          return license.licensetype === "SPECIAL INSPECTION AGENCY" || license.licensetype === "SPECIAL INSPECTOR";
        }).length > 0));
      
    },


    scrollToTop : function () {
      window.scrollTo({
        top: 0,
        behavior: 'smooth',
      });
    },

    isMobile() {
      if( window.innerWidth <= 760 ) {
        return true;
      }
      return false;
    },

    clearSearchBar: function () {
      this.search = "";
    },

    updateRouterQuery: function (key, value) {
      if (!value) {
        Vue.delete(this.routerQuery, key);
      } else {
        Vue.set(this.routerQuery, key, value);
        if (key === 'search'){
          this.$ga.event('licensed-contractor', 'search', value);
        } else if (key === 'licenseType' ) {
          this.$ga.event('licensed-contractor', 'contractor-type', value);
        }
      }
    },
    resetRouterQuery: function () {
      for (let routeKey in this.$route.query) {
        Vue.delete(this.routerQuery, routeKey);
      }
    },

    updateRouter: function () {
      if (this.routerQuery  === this.$route.query) {
        return;
      } 
      this.$router.push({
        name: 'main',
        query: this.routerQuery,
      }).catch(e => {
        // window.console.log(e);
      });
    },

    initFilters: function() {
      if (Object.keys(this.$route.query).length !== 0) {
        for (let routerKey in this.$route.query) {
          Vue.set(this, routerKey, this.$route.query[routerKey]);
        }
      }
    },

  },
};
</script>

<style lang="scss" >

@import 'node_modules/vue-select/dist/vue-select';

#finder-app {
   padding-bottom: 70px;
  
  .filter-by {
    width: 100%;
    margin: 0px auto 0 auto;
    display: flex;
    flex-direction: row;
    position: sticky;
    position: -webkit-sticky; //for safari
    top: 86px;
    z-index:100;
    width: 100%;
    background-color: white;
    padding: 30px 7.5% 14px 7.5%;
    box-shadow: 5px 5px 10px lightgrey;

    .search{
      width: 50%;
      margin-right: 5px;

      .clear-search-btn {
      position: absolute;
      top:16px;
      right: 70px;
      padding: 0;
      font-size: 20px;
      background-color: #fff;
      opacity: 0.8;
      z-index: 999;
      cursor: pointer;
      color: rgba(60, 60, 60, 0.5);
      }
    }

    .select-license-type {
      width: 50%;
      margin-left: 5px;
      .v-select {
        background-color: white;
        font-family:"Open Sans", Helvetica, Roboto, Arial, sans-serif !important;
        
        .vs__dropdown-toggle {
           border-radius: 0;
           padding:0;
          border: solid 2px #0f4d90;
          height: 54px;

          .vs__selected-options{

            .vs__selected {
               position: absolute;
              font-size: 16px;
              line-height: 40px;
            }

            .vs__search {
              color: #a1a1a1;
              background: white;
              
              &:focus {
                border: none !important;
              }
            }
          }

          .vs__actions {
            padding:0 5px 0 0;
           

            .vs__open-indicator path {
               cursor: pointer;
              fill: #0f4d90;
            }

            .vs__clear:hover {
              background-color: transparent;
            }
          }

        }

        .vs__dropdown-menu {
          font-weight: bold;
          margin-top: 1px;
          z-index: 1000;

          .vs__dropdown-option {
            border-bottom: 1px solid #f0f0f0;
            padding: 15px 0 15px 10px;
          }

          .vs__dropdown-option--highlight {
            background: #0f4d90;
            color: white;
          }
        }
      }
    }
  }

  .table-container {
     max-width: 85%;
    margin:0px auto 0px auto;

    table {
      margin-top: 28px;
    }
    
    .license-holder {
      font-weight: bold;
      font-size: 16px;
    }

    .license-holder-title{
     min-width: 30%;
    }

    .company-name {
      width: 20%;
    }

    .special-categories {
      width: 25%;
    }

    .contractor-type {
      width: 17%;
    }

    .license-number {
      width: 10%;
      text-align: right;
      font-weight: bold;
    }
  }

  .app-pages{
    display: flex;
    justify-content: space-between;

    p {
      padding-left: 3px;
    }
  }

  @media (max-width: 760px) {

    .logo {
      width: 170px;
    }

    .filter-by {
      display: flex;
      flex-direction: column;
       padding: 15px 2.5% 10px 2.5%;
       position: relative;
       top: 0;

      .search {
        width: 100%  ;
        margin-right: 0;
      }

      .select-license-type {
        width: 100% ;
        margin-left: 0;
      }
    }

    .app-pages{
    display: flex;
    flex-direction: column-reverse;
      p {
        margin: 0 auto;
      }
      ul {
        margin: 0 auto;
      }
    }
  }
}

</style>