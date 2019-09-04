<template>
  <div id="finder-app">
    <div class="filter-by">
      <div class="search">
        <input
          id="search-bar"
          v-model="search"
          class="search-field"
          type="text"
          placeholder="Search by license holder, company, or number"
          @keyup.enter="filter()"
        >
        
        <input
          ref="archive-search-bar"
          type="submit"
          class="search-submit"
          value="Search"
          @click="filter()"
        >
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
          class="sticky center"
          data-sticky
          data-top-anchor="filter-results:bottom"
          data-btm-anchor="page:bottom"
        >
          <tr>
            <th class="license-holder-title">
              <span>License Holder</span>
            </th>
            <th 
              v-if="!mobile"
              class="company-name"
            >
              <span>Company Name</span>
            </th>
            <th 
              v-if="specialCategories"
              class="special-categories"
            >
              <span>Special Inspection Categories</span>
            </th>
            <th 
              v-if="!mobile"
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
          :per="25"
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
              v-if="!mobile"
              class="company-name"
            >
              {{ license.companyname | upperCase }}
            </td>
            <td
              v-if="specialCategories"
              class="special-categories"
            >
              {{ license.icccategory }}
            </td>
            <td
              v-if="!mobile"
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
          v-show="!loading && !emptyResponse && !failure && displayPaginate"
          for="filteredLicenses"
          :async="true"
          :limit="3"
          :show-step-links="true"
          :hide-single-page="false"
          :step-links="{
            next: 'Next',
            prev: 'Previous'
          }"
          @change="scrollToTop"
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

Vue.use(VuePaginate);
Vue.use(VueFuse);

const serviceURL = "https://data.phila.gov/carto/api/v2/sql?q=";
const query_base = "SELECT contactname, companyname, icccategory, licensenumber, licensetype FROM li_trade_licenses WHERE licensestatus = 'ACTIVE'";

const licensetype_query = "SELECT DISTINCT licensetype FROM li_trade_licenses";
const licensetype_query_counts = "SELECT licensetype, COUNT(1) as licensecount FROM li_trade_licenses WHERE licensestatus = 'ACTIVE' GROUP BY licensetype";

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
      displayPaginate: true,
      mobile: false,
      paginate: [ 'filteredLicenses' ],
      searchOptions: {
        threshold: 0.15, 
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
    };
  },
  computed: { 
    numberOf : function() {
      return this.filteredLicenses.length;
    },
  },

  watch: {
    licenseType: function() {
      this.filter();
    },

    search: function() {
      this.filter();
    },
    
    loading : function(val) {
      if (val === false) {
        this.countLicenses();
      }
    },
  },

  mounted: async function() {
    this.getAllLicenses();
    this.getLicenseTypes();
  },
  
  created() {
    window.addEventListener('resize', this.onResize);
  },

  beforeDestroy() {
    window.removeEventListener('resize', this.onResize);
  },

  methods: {
    getAllLicenses: function() {
      {
        axios
          .get(serviceURL+query_base)
          .then(response => {
            this.licenses = response.data;

            // sorted by name -- doesnt work due to null values
            // this.sortedLicenses = this.licenses.rows.sort(function(a, b){
            //     if(a.contactname.trim() < b.contactname.trim()) { return -1; }
            //     if(a.contactname.trim() > b.contactname.trim()) { return 1; }
            //   return 0;});
            
            // sorted by license number
            this.sortedLicenses = this.licenses.rows.sort(function (a, b) {
              return a.licensenumber - b.licensenumber;
            });
            this.filteredLicenses = this.sortedLicenses;
            this.loading = false;
            
            
          })
          .catch(e => {
            window.console.log(e);
            this.failure = true;
            this.loading = false;
          });
      }
    },

    getLicenseTypes: function() {
      {
        axios
          .get(serviceURL+licensetype_query)
          .then(response => {
            this.licenseTypes = response.data.rows;
            this.licenseTypes = this.licenseTypes.map(function(x) {
              return (x.licensetype);
            }).sort();
            
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
      if (this.search !== '' && this.search !== null ) {
        this.$search(this.search, this.filteredLicenses, this.searchOptions).then(licenses => {
          this.filteredLicenses = licenses;
        }); 
      } 
    },

    filterByType: function() {
      if (this.licenseType !== '' && this.licenseType !== null ) {

        let categoryNoCount = this.licenseType.split(" (")[0];
        //only add special categories column if these are selected, or all contractors are selected
        if (categoryNoCount === "Special Inspection Agency" || categoryNoCount === "Special Inspector") {
          this.specialCategories = true;
        }
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
    },

    toTitleCase: function(str) {
      if (str !== null && str !== undefined){

        return str.replace(/\w\S*/g, function(txt){
          return txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase();
            
        });
      }
    },

    checkEmpty: function() {
      this.emptyResponse = (this.filteredLicenses.length === 0) ? true : false;
      this.displayPaginate = (this.filteredLicenses.length > 25) ? true : false;
    },

    scrollToTop : function () {
      window.scrollTo({
        top: 0,
        behavior: 'smooth',
      });
    },

    onResize() {
      if (window.innerWidth <= 750) {
        this.mobile = true;
      } else {
        this.mobile = false;
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
    background-color: #25cef7;
    background-color: white;
    padding: 30px 7.5% 14px 7.5%;
    border-bottom: solid 2px #0f4d90;

    .search{
      width: 50%;
      margin-right: 5px;
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

      td {
      border: 3px solid white;
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
  }

  @media (max-width: 800px) {

    .logo {
      width: 170px;
    }

    .filter-by {
      display: flex;
      flex-direction: column;
       padding: 15px 2.5% 10px 2.5%;
       position: relative;

      .search {
        width: 100%  ;
        margin-right: 0;
      }

      .select-license-type {
        width: 100% ;
        margin-left: 0;
      }
    }
    .table-container {
      // max-width: 95%;
      
      table {
        // max-width: 375px;
      }
    }
  }
}


</style>