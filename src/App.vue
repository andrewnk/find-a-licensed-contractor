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
        ><input
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
          :options="licenseTypes"
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
          data-options="marginTop:4.8;"
        >
          <tr>
            <th class="license-holder-title">
              <span>License Holder</span>
            </th>
            <th class="company-name">
              <span>Company Name</span>
            </th>
            <th 
              v-if="specialCategories"
              class="special-categories"
            >
              <span>Special Inspection Categories</span>
            </th>
            <th class="contractor-type">
              <span>Contractor Type</span>
            </th>
            <th class="license-number">
              <span>License #</span>
            </th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="license in filteredLicenses"
            :key="license.licensenumber"
            class="license-row" 
          >
            <td
              class="license-holder"
            >
              {{ license.contactname | upperCase }}
            </td>
            <td
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
        </tbody>
      </table>
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
      filteredLicenses: [],
      sortedLicenses: [],
      loading: true,
      emptyResponse: false,
      failure: false,
      specialCategories: false,
      searchOptions: {
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
    };
  },
  computed: { 
    
  },

  watch: {
    licenseType: function() {
      this.filter();
    },

    // search: function() {
    //   this.filter();
    // },
  },

  mounted: function() {
    this.getAllLicenses();
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
            this.getLicenseTypes();
          })
          .catch(e => {
            window.console.log(e);
            this.failure = true;
            this.loading = false;
          });
      }
    },

    getLicenseTypes: function() {
      this.licenses.rows.forEach((license) => {
        let newLicenseType = license.licensetype;
        if (newLicenseType !== null && newLicenseType !== '') {
          this.licenseTypes.push(this.toTitleCase(newLicenseType));
        }
      });

      this.licenseTypes =  this.licenseTypes.filter((item, index) => this.licenseTypes.indexOf(item) === index).sort();

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
        //only add special categories column if these are selected, or all contractors are selected
        if (this.licenseType === "Special Inspection Agency" || this.licenseType === "Special Inspector") {
          this.specialCategories = true;
        }
        this.$search(this.licenseType, this.filteredLicenses, this.contractorOptions).then(licenses => {
          this.filteredLicenses = licenses;
        });
      } 
    },

    filter: async function() {
      this.filteredLicenses = this.sortedLicenses;
      this.specialCategories = false;
      await this.filterByType();
      await this.filterBySearch();
      
    },

    toTitleCase: function(str) {
      return str.replace(/\w\S*/g, function(txt){
        return txt.charAt(0).toUpperCase() + txt.substr(1).toLowerCase();
      });
    },

  },
};
</script>

<style lang="scss" >

@import 'node_modules/vue-select/dist/vue-select';


#finder-app {
  max-width: 85%;
  margin: 0 auto;
  padding-bottom: 30px;

  .filter-by {
    display: flex;
    flex-direction: row;
    position: sticky;
    position: -webkit-sticky; //for safari
    top: 0;
    z-index:100;
    width: 100%;
    background-color: white;
    padding-top: 15px;
    border-bottom: solid 2px #0f4d90;

    .search{
      width: 50%;
      margin-right: 5px;
    }

    .select-license-type {
      width: 50%;
      margin-left: 5px;
      .v-select {
         
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

    table, th , td {
      border: 3px solid white;
    }
    
    .license-holder {
      font-weight: bold;
      font-size: 16px;
        width: 50%;
    }

    .license-holder-title{
     min-width: 30%;
     width: 50%;
    }

    .company-name {
      max-width: 20%;
    }

    .special-categories {
      width: 25%;
    }

    .contractor-type {
      width: 15%;
    }

    .license-number {
      max-width: 10%;
      text-align: right;
      font-weight: bold;
    }
  }
}

</style>